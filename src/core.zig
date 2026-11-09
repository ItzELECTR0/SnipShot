const std = @import("std");

extern "c" fn popen(command: [*:0]const u8, mode: [*:0]const u8) ?*anyopaque;
extern "c" fn pclose(stream: *anyopaque) c_int;
extern "c" fn fgets(buffer: [*]u8, size: c_int, stream: *anyopaque) ?[*:0]u8;
extern "c" fn getenv(name: [*:0]const u8) ?[*:0]u8;
extern "c" fn mkdir(path: [*:0]const u8, mode: c_uint) c_int;
extern "c" fn access(path: [*:0]const u8, mode: c_int) c_int;
extern "c" fn time(result: ?*i64) i64;
extern "c" fn getpid() c_int;
extern "c" fn fork() c_int;
extern "c" fn execvp(file: [*:0]const u8, argv: [*:null]?[*:0]const u8) c_int;
extern "c" fn _exit(status: c_int) noreturn;
extern "c" fn waitpid(pid: c_int, status: *c_int, options: c_int) c_int;
extern "c" fn pipe(descriptors: *[2]c_int) c_int;
extern "c" fn close(fd: c_int) c_int;
extern "c" fn dup2(old_fd: c_int, new_fd: c_int) c_int;
extern "c" fn read(fd: c_int, buffer: [*]u8, count: usize) isize;
extern "c" fn kill(pid: c_int, signal: c_int) c_int;
extern "c" fn fcntl(fd: c_int, command: c_int, argument: c_int) c_int;
extern "c" fn write(fd: c_int, buffer: [*]const u8, count: usize) isize;
extern "c" fn unlink(path: [*:0]const u8) c_int;
extern "c" fn fopen(path: [*:0]const u8, mode: [*:0]const u8) ?*anyopaque;
extern "c" fn fwrite(buffer: [*]const u8, size: usize, count: usize, stream: *anyopaque) usize;
extern "c" fn fclose(stream: *anyopaque) c_int;

const allocator = std.heap.page_allocator;
const file_exists = 0;
const stdout_fd = 1;
const sigint = 2;
const set_fd_flags = 2;
const close_on_exec = 1;
var active_recorder = std.atomic.Value(c_int).init(-1);
var file_sequence = std.atomic.Value(u64).init(0);
var recording_region: ?[:0]u8 = null;
var recording_path: ?[:0]u8 = null;
var recording_paused = false;
var segment_count: usize = 0;
var segments: [256]?[:0]u8 = undefined;

const SnipShotRegion = extern struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};

fn copyOut(destination: [*]u8, capacity: usize, value: []const u8) void {
    if (capacity == 0) return;
    const count = @min(capacity - 1, value.len);
    @memcpy(destination[0..count], value[0..count]);
    destination[count] = 0;
}

fn selectRegion() ?[:0]u8 {
    const stream = popen("slurp", "r") orelse return null;
    var line: [4096]u8 = undefined;
    if (fgets(&line, @intCast(line.len), stream) == null) {
        _ = pclose(stream);
        return null;
    }
    if (pclose(stream) != 0) return null;
    return std.fmt.allocPrintSentinel(allocator, "{s}", .{std.mem.trim(u8, std.mem.sliceTo(&line, 0), "\r\n")}, 0) catch null;
}

fn parseRegion(region: [:0]const u8, output: *SnipShotRegion) bool {
    const value = region[0..region.len];
    const comma = std.mem.indexOfScalar(u8, value, ',') orelse return false;
    const separator = std.mem.indexOfScalarPos(u8, value, comma + 1, ' ') orelse return false;
    const x_separator = std.mem.indexOfScalarPos(u8, value, separator + 1, 'x') orelse return false;
    output.x = std.fmt.parseInt(c_int, value[0..comma], 10) catch return false;
    output.y = std.fmt.parseInt(c_int, value[comma + 1 .. separator], 10) catch return false;
    output.width = std.fmt.parseInt(c_int, value[separator + 1 .. x_separator], 10) catch return false;
    output.height = std.fmt.parseInt(c_int, value[x_separator + 1 ..], 10) catch return false;
    return output.width > 0 and output.height > 0;
}

fn outputPath(kind: []const u8, extension: []const u8) ![:0]u8 {
    const override = getenv("SNIPSHOT_OUTPUT_DIR");
    const home = getenv("HOME") orelse return error.HomeNotFound;
    const base = if (override) |directory|
        try allocator.dupe(u8, std.mem.span(directory))
    else if (std.mem.eql(u8, kind, "Screenshot"))
        try std.fmt.allocPrint(allocator, "{s}/Pictures/SnipShot", .{std.mem.span(home)})
    else
        try std.fmt.allocPrint(allocator, "{s}/Videos/SnipShot", .{std.mem.span(home)});
    defer allocator.free(base);

    const directory_z = try std.fmt.allocPrintSentinel(allocator, "{s}", .{base}, 0);
    defer allocator.free(directory_z);
    if (mkdir(directory_z, 0o755) != 0 and access(directory_z, file_exists) != 0) {
        return error.OutputDirectoryUnavailable;
    }

    const filename = try std.fmt.allocPrint(allocator, "{s}-{d}-{d}-{d}.{s}", .{
        kind,
        time(null),
        getpid(),
        file_sequence.fetchAdd(1, .seq_cst),
        extension,
    });
    defer allocator.free(filename);
    return std.fmt.allocPrintSentinel(allocator, "{s}/{s}", .{ base, filename }, 0);
}

fn runTool(argv: []const [*:0]const u8) bool {
    const child = fork();
    if (child < 0) return false;
    if (child == 0) {
        var args: [16:null]?[*:0]const u8 = .{ null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null };
        for (argv, 0..) |arg, index| args[index] = arg;
        _ = execvp(argv[0], &args);
        _exit(127);
    }
    var status: c_int = 0;
    if (waitpid(child, &status, 0) < 0) return false;
    return status == 0;
}

fn recognize(image: [:0]const u8, destination: [*]u8, capacity: usize) bool {
    var descriptors: [2]c_int = undefined;
    if (pipe(&descriptors) != 0) return false;
    const child = fork();
    if (child < 0) {
        _ = close(descriptors[0]);
        _ = close(descriptors[1]);
        return false;
    }
    if (child == 0) {
        _ = close(descriptors[0]);
        _ = dup2(descriptors[1], stdout_fd);
        _ = close(descriptors[1]);
        var args: [4:null]?[*:0]const u8 = .{ "tesseract", image, "stdout", null };
        _ = execvp(args[0].?, &args);
        _exit(127);
    }

    _ = close(descriptors[1]);
    var used: usize = 0;
    var buffer: [4096]u8 = undefined;
    while (true) {
        const count = read(descriptors[0], &buffer, buffer.len);
        if (count <= 0) break;
        const size: usize = @intCast(count);
        if (capacity > 0 and used < capacity - 1) {
            const copied = @min(size, capacity - 1 - used);
            @memcpy(destination[used .. used + copied], buffer[0..copied]);
            used += copied;
        }
    }
    _ = close(descriptors[0]);
    if (capacity > 0) destination[used] = 0;
    var status: c_int = 0;
    if (waitpid(child, &status, 0) < 0) return false;
    return status == 0;
}

fn stopRecorder(errbuf: [*]u8, error_capacity: usize) bool {
    const pid = active_recorder.swap(-1, .seq_cst);
    if (pid <= 0) {
        copyOut(errbuf, error_capacity, "No recording is running");
        return false;
    }
    _ = kill(pid, sigint);
    var status: c_int = 0;
    if (waitpid(pid, &status, 0) < 0 or status != 0) {
        copyOut(errbuf, error_capacity, "The recording process did not finish cleanly");
        return false;
    }
    return true;
}

fn startRecorder(region: [:0]const u8, destination: [:0]const u8, errbuf: [*]u8, error_capacity: usize) bool {
    var startup_pipe: [2]c_int = undefined;
    if (pipe(&startup_pipe) != 0) {
        copyOut(errbuf, error_capacity, "Could not prepare the recording process");
        return false;
    }
    if (fcntl(startup_pipe[1], set_fd_flags, close_on_exec) < 0) {
        _ = close(startup_pipe[0]);
        _ = close(startup_pipe[1]);
        copyOut(errbuf, error_capacity, "Could not prepare the recording process");
        return false;
    }
    const child = fork();
    if (child < 0) {
        _ = close(startup_pipe[0]);
        _ = close(startup_pipe[1]);
        copyOut(errbuf, error_capacity, "Could not start recording");
        return false;
    }
    if (child == 0) {
        _ = close(startup_pipe[0]);
        var args: [6:null]?[*:0]const u8 = .{ "wf-recorder", "-g", region, "-f", destination, null };
        _ = execvp(args[0].?, &args);
        const code: c_int = -1;
        _ = write(startup_pipe[1], @ptrCast(&code), @sizeOf(c_int));
        _exit(127);
    }
    _ = close(startup_pipe[1]);
    var exec_error: c_int = 0;
    const startup_result = read(startup_pipe[0], @ptrCast(&exec_error), @sizeOf(c_int));
    _ = close(startup_pipe[0]);
    if (startup_result > 0) {
        var status: c_int = 0;
        _ = waitpid(child, &status, 0);
        copyOut(errbuf, error_capacity, "Could not launch wf-recorder");
        return false;
    }
    active_recorder.store(child, .seq_cst);
    return true;
}

fn writeConcatList(path: [:0]const u8) ?[:0]u8 {
    const list_path = std.fmt.allocPrintSentinel(allocator, "{s}.concat", .{path[0..path.len]}, 0) catch return null;
    const stream = fopen(list_path, "w") orelse {
        allocator.free(list_path);
        return null;
    };
    for (segments[0..segment_count]) |maybe_segment| {
        const segment = maybe_segment orelse continue;
        _ = fwrite("file '", 1, 6, stream);
        for (segment[0..segment.len]) |character| {
            if (character == '\'') {
                _ = fwrite("'\\''", 1, 4, stream);
            } else {
                _ = fwrite(@ptrCast(&character), 1, 1, stream);
            }
        }
        _ = fwrite("'\n", 1, 2, stream);
    }
    if (fclose(stream) != 0) {
        allocator.free(list_path);
        return null;
    }
    return list_path;
}

fn clearRecordingState(delete_segments: bool) void {
    for (segments[0..segment_count]) |maybe_segment| {
        if (maybe_segment) |segment| {
            if (delete_segments) _ = unlink(segment);
            allocator.free(segment);
        }
    }
    if (recording_region) |region| allocator.free(region);
    if (recording_path) |path| allocator.free(path);
    recording_region = null;
    recording_path = null;
    segment_count = 0;
    recording_paused = false;
}

fn startNextSegment(errbuf: [*]u8, error_capacity: usize) bool {
    if (segment_count >= segments.len) {
        copyOut(errbuf, error_capacity, "Too many pause and resume cycles");
        return false;
    }
    const final_path = recording_path orelse return false;
    const segment = std.fmt.allocPrintSentinel(allocator, "{s}.part-{d:0>3}.mkv", .{ final_path[0..final_path.len], segment_count }, 0) catch {
        copyOut(errbuf, error_capacity, "Could not prepare a recording segment");
        return false;
    };
    const region = recording_region orelse {
        allocator.free(segment);
        return false;
    };
    if (!startRecorder(region, segment, errbuf, error_capacity)) {
        allocator.free(segment);
        return false;
    }
    segments[segment_count] = segment;
    segment_count += 1;
    return true;
}

export fn snipshot_capture(
    extract_text: c_int,
    path: [*]u8,
    path_capacity: usize,
    text: [*]u8,
    text_capacity: usize,
    errbuf: [*]u8,
    error_capacity: usize,
) c_int {
    const region = selectRegion() orelse return 1;
    defer allocator.free(region);
    const destination = outputPath("Screenshot", "png") catch {
        copyOut(errbuf, error_capacity, "Could not create the screenshot folder");
        return 2;
    };
    defer allocator.free(destination);
    if (!runTool(&.{ "grim", "-g", region, destination })) {
        copyOut(errbuf, error_capacity, "Screenshot failed. Check capture permissions.");
        return 2;
    }
    copyOut(path, path_capacity, destination);
    if (extract_text != 0 and !recognize(destination, text, text_capacity)) {
        copyOut(errbuf, error_capacity, "Text recognition failed");
        return 2;
    }
    return 0;
}

export fn snipshot_record_start(
    path: [*]u8,
    path_capacity: usize,
    output_region: *SnipShotRegion,
    errbuf: [*]u8,
    error_capacity: usize,
) c_int {
    if (recording_path != null or active_recorder.load(.seq_cst) > 0) {
        copyOut(errbuf, error_capacity, "A recording is already running");
        return 2;
    }
    const region = selectRegion() orelse return 1;
    if (!parseRegion(region, output_region)) {
        allocator.free(region);
        copyOut(errbuf, error_capacity, "Could not read the selected recording region");
        return 2;
    }
    const destination = outputPath("Recording", "mkv") catch {
        allocator.free(region);
        copyOut(errbuf, error_capacity, "Could not create the video folder");
        return 2;
    };
    recording_region = region;
    recording_path = destination;
    recording_paused = false;
    segment_count = 0;
    if (!startNextSegment(errbuf, error_capacity)) {
        clearRecordingState(false);
        return 2;
    }
    copyOut(path, path_capacity, destination);
    return 0;
}

export fn snipshot_record_pause(pause: c_int, errbuf: [*]u8, error_capacity: usize) c_int {
    if (recording_path == null) {
        copyOut(errbuf, error_capacity, "No recording is running");
        return 2;
    }
    const should_pause = pause != 0;
    if (should_pause == recording_paused) return 0;
    if (should_pause) {
        if (!stopRecorder(errbuf, error_capacity)) return 2;
        recording_paused = true;
        return 0;
    }
    if (!startNextSegment(errbuf, error_capacity)) return 2;
    recording_paused = false;
    return 0;
}

export fn snipshot_record_abort(errbuf: [*]u8, error_capacity: usize) c_int {
    if (recording_path == null) return 0;
    if (active_recorder.load(.seq_cst) > 0 and !stopRecorder(errbuf, error_capacity)) return 2;
    clearRecordingState(true);
    return 0;
}

export fn snipshot_record_stop(errbuf: [*]u8, error_capacity: usize) c_int {
    if (recording_path == null) {
        copyOut(errbuf, error_capacity, "No recording is running");
        return 2;
    }
    if (active_recorder.load(.seq_cst) > 0 and !stopRecorder(errbuf, error_capacity)) return 2;

    const final_path = recording_path.?;
    const concat_path = writeConcatList(final_path) orelse {
        copyOut(errbuf, error_capacity, "Could not prepare the recording for export");
        clearRecordingState(false);
        return 2;
    };
    defer allocator.free(concat_path);
    if (!runTool(&.{ "ffmpeg", "-nostdin", "-y", "-f", "concat", "-safe", "0", "-i", concat_path, "-c", "copy", final_path })) {
        copyOut(errbuf, error_capacity, "Could not join the recording segments. The segments were kept.");
        clearRecordingState(false);
        return 2;
    }
    _ = unlink(concat_path);
    clearRecordingState(true);
    return 0;
}
