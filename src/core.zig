const std = @import("std");
const builtin = @import("builtin");

extern "c" fn getenv(name: [*:0]const u8) ?[*:0]u8;
extern "c" fn mkdir(path: [*:0]const u8, mode: c_uint) c_int;
extern "c" fn access(path: [*:0]const u8, mode: c_int) c_int;
extern "c" fn time(result: ?*i64) i64;
extern "c" fn localtime_r(timer: *const i64, result: *Tm) ?*Tm;
extern "c" fn strftime(buffer: [*]u8, size: usize, format: [*:0]const u8, tm: *const Tm) usize;
extern "c" fn getuid() c_uint;
extern "c" fn fork() c_int;
extern "c" fn execvp(file: [*:0]const u8, argv: [*:null]const ?[*:0]const u8) c_int;
extern "c" fn _exit(status: c_int) noreturn;
extern "c" fn waitpid(pid: c_int, status: *c_int, options: c_int) c_int;
extern "c" fn pipe2(descriptors: *[2]c_int, flags: c_int) c_int;
extern "c" fn close(fd: c_int) c_int;
extern "c" fn dup2(old_fd: c_int, new_fd: c_int) c_int;
extern "c" fn open(path: [*:0]const u8, flags: c_int, ...) c_int;
extern "c" fn read(fd: c_int, buffer: [*]u8, count: usize) isize;
extern "c" fn write(fd: c_int, buffer: [*]const u8, count: usize) isize;
extern "c" fn lseek(fd: c_int, offset: i64, whence: c_int) i64;
extern "c" fn kill(pid: c_int, signal: c_int) c_int;
extern "c" fn unlink(path: [*:0]const u8) c_int;
extern "c" fn rename(old: [*:0]const u8, new: [*:0]const u8) c_int;
extern "c" fn usleep(microseconds: c_uint) c_int;

const Tm = extern struct {
    sec: c_int,
    min: c_int,
    hour: c_int,
    mday: c_int,
    mon: c_int,
    year: c_int,
    wday: c_int,
    yday: c_int,
    isdst: c_int,
    gmtoff: c_long,
    zone: ?[*:0]const u8,
};

const allocator = std.heap.page_allocator;
const stdin_fd = 0;
const stdout_fd = 1;
const stderr_fd = 2;
const sigint = 2;
const sigusr2 = 12;
const o_cloexec = 0o2000000;
const wnohang = 1;
const f_ok = 0;
const x_ok = 1;
const o_rdonly = 0;
const o_write_create_truncate = 0o1101;
const seek_end = 2;

pub const Result = enum(c_int) { ok = 0, cancelled = 1, failed = 2, unsupported = 3 };

pub const Backend = enum(c_int) { auto = 0, gpu_screen_recorder = 1, wf_recorder = 2 };

pub const Kind = enum(c_int) { screenshot = 0, recording = 1 };

const SnipShotRegion = extern struct {
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
};

const SnipShotRecordOptions = extern struct {
    region: SnipShotRegion,
    backend: c_int,
    microphone: c_int,
    system_audio: c_int,
    framerate: c_int,
    directory: ?[*:0]const u8,
};

const Recording = struct {
    backend: Backend,
    final_path: [:0]u8,
    region: SnipShotRegion,
    microphone: bool,
    system_audio: bool,
    framerate: c_int,
    paused: bool = false,
    recorder: c_int = -1,
    mic_recorder: c_int = -1,
    segments: std.ArrayList([:0]u8) = .empty,
    mic_segments: std.ArrayList([:0]u8) = .empty,
};

var recording: ?Recording = null;

fn copyOut(destination: [*]u8, capacity: usize, value: []const u8) void {
    if (capacity == 0) return;
    const count = @min(capacity - 1, value.len);
    @memcpy(destination[0..count], value[0..count]);
    destination[count] = 0;
}

fn fail(errbuf: [*]u8, error_capacity: usize, message: []const u8) c_int {
    copyOut(errbuf, error_capacity, message);
    return @intFromEnum(Result.failed);
}

fn z(comptime format: []const u8, args: anytype) ![:0]u8 {
    return std.fmt.allocPrintSentinel(allocator, format, args, 0);
}

fn ensureDirectory(path: [:0]const u8) bool {
    if (mkdir(path, 0o700) == 0) return true;
    return access(path, f_ok) == 0;
}

fn ensureDirectoryTree(path: []const u8) bool {
    var index: usize = 1;
    while (index <= path.len) : (index += 1) {
        if (index != path.len and path[index] != '/') continue;
        const prefix = z("{s}", .{path[0..index]}) catch return false;
        defer allocator.free(prefix);
        if (mkdir(prefix, 0o755) != 0 and access(prefix, f_ok) != 0) return false;
    }
    return true;
}

fn runtimeDirectory() ![:0]u8 {
    const directory = if (getenv("XDG_RUNTIME_DIR")) |runtime|
        try z("{s}/snipshot", .{std.mem.span(runtime)})
    else
        try z("/tmp/snipshot-{d}", .{getuid()});
    if (!ensureDirectory(directory)) {
        allocator.free(directory);
        return error.RuntimeDirectoryUnavailable;
    }
    return directory;
}

fn defaultDirectory(kind: Kind) ![]u8 {
    if (getenv("SNIPSHOT_OUTPUT_DIR")) |directory| return allocator.dupe(u8, std.mem.span(directory));
    const home = std.mem.span(getenv("HOME") orelse return error.HomeNotFound);
    return switch (kind) {
        .screenshot => std.fmt.allocPrint(allocator, "{s}/Pictures/SnipShot", .{home}),
        .recording => std.fmt.allocPrint(allocator, "{s}/Videos/SnipShot", .{home}),
    };
}

fn timestamp(buffer: []u8) []const u8 {
    const now = time(null);
    var tm: Tm = undefined;
    if (localtime_r(&now, &tm) == null) return "unknown";
    const count = strftime(buffer.ptr, buffer.len, "%Y-%m-%d %H%M%S", &tm);
    return buffer[0..count];
}

fn outputPath(kind: Kind, configured: ?[*:0]const u8, extension: []const u8) ![:0]u8 {
    const configured_dir: ?[]const u8 = if (configured) |value| (if (value[0] != 0) std.mem.span(value) else null) else null;
    const base = if (getenv("SNIPSHOT_OUTPUT_DIR") == null and configured_dir != null)
        try allocator.dupe(u8, configured_dir.?)
    else
        try defaultDirectory(kind);
    defer allocator.free(base);
    if (!ensureDirectoryTree(base)) return error.OutputDirectoryUnavailable;

    var stamp_buffer: [64]u8 = undefined;
    const stamp = timestamp(&stamp_buffer);
    const prefix = if (kind == .screenshot) "Screenshot" else "Screen Recording";
    var attempt: usize = 1;
    while (attempt < 1000) : (attempt += 1) {
        const candidate = if (attempt == 1)
            try z("{s}/{s} {s}.{s}", .{ base, prefix, stamp, extension })
        else
            try z("{s}/{s} {s} ({d}).{s}", .{ base, prefix, stamp, attempt, extension });
        if (access(candidate, f_ok) != 0) return candidate;
        allocator.free(candidate);
    }
    return error.OutputPathUnavailable;
}

fn findInPath(name: []const u8) bool {
    const path = std.mem.span(getenv("PATH") orelse return false);
    var entries = std.mem.tokenizeScalar(u8, path, ':');
    while (entries.next()) |entry| {
        const candidate = z("{s}/{s}", .{ entry, name }) catch return false;
        defer allocator.free(candidate);
        if (access(candidate, x_ok) == 0) return true;
    }
    return false;
}

const Spawn = struct {
    argv: []const ?[*:0]const u8,
    stdin_path: ?[*:0]const u8 = null,
    stdin_fd: c_int = -1,
    stdout_fd: c_int = -1,
    log_path: ?[*:0]const u8 = null,
};

fn spawn(options: Spawn) ?c_int {
    var exec_pipe: [2]c_int = undefined;
    if (pipe2(&exec_pipe, o_cloexec) != 0) return null;
    var argv: [32:null]?[*:0]const u8 = @splat(null);
    if (options.argv.len >= argv.len) return null;
    for (options.argv, 0..) |arg, index| argv[index] = arg;

    const child = fork();
    if (child < 0) {
        _ = close(exec_pipe[0]);
        _ = close(exec_pipe[1]);
        return null;
    }
    if (child == 0) {
        _ = close(exec_pipe[0]);
        if (options.stdin_fd >= 0) {
            _ = dup2(options.stdin_fd, stdin_fd);
        } else {
            const input = open(options.stdin_path orelse "/dev/null", o_rdonly);
            if (input >= 0) _ = dup2(input, stdin_fd);
        }
        if (options.stdout_fd >= 0) _ = dup2(options.stdout_fd, stdout_fd);
        if (options.log_path) |log| {
            const output = open(log, o_write_create_truncate, @as(c_uint, 0o600));
            if (output >= 0) {
                if (options.stdout_fd < 0) _ = dup2(output, stdout_fd);
                _ = dup2(output, stderr_fd);
            }
        }
        _ = execvp(argv[0].?, &argv);
        const code: c_int = 127;
        _ = write(exec_pipe[1], @ptrCast(&code), @sizeOf(c_int));
        _exit(127);
    }
    _ = close(exec_pipe[1]);
    var exec_error: c_int = 0;
    const exec_failed = read(exec_pipe[0], @ptrCast(&exec_error), @sizeOf(c_int)) > 0;
    _ = close(exec_pipe[0]);
    if (exec_failed) {
        var status: c_int = 0;
        _ = waitpid(child, &status, 0);
        return null;
    }
    return child;
}

fn exitedCleanly(status: c_int) bool {
    return status & 0x7f == 0 and (status >> 8) & 0xff == 0;
}

fn wait(pid: c_int) bool {
    var status: c_int = 0;
    if (waitpid(pid, &status, 0) < 0) return false;
    return exitedCleanly(status);
}

fn run(argv: []const ?[*:0]const u8) bool {
    const pid = spawn(.{ .argv = argv }) orelse return false;
    return wait(pid);
}

fn runCapture(argv: []const ?[*:0]const u8) ?[]u8 {
    var descriptors: [2]c_int = undefined;
    if (pipe2(&descriptors, o_cloexec) != 0) return null;
    const pid = spawn(.{ .argv = argv, .stdout_fd = descriptors[1], .log_path = "/dev/null" }) orelse {
        _ = close(descriptors[0]);
        _ = close(descriptors[1]);
        return null;
    };
    _ = close(descriptors[1]);
    var output: std.ArrayList(u8) = .empty;
    var buffer: [16384]u8 = undefined;
    while (true) {
        const count = read(descriptors[0], &buffer, buffer.len);
        if (count <= 0) break;
        output.appendSlice(allocator, buffer[0..@intCast(count)]) catch break;
    }
    _ = close(descriptors[0]);
    if (!wait(pid)) {
        output.deinit(allocator);
        return null;
    }
    return output.toOwnedSlice(allocator) catch null;
}

fn fileSize(path: [*:0]const u8) i64 {
    const fd = open(path, o_rdonly);
    if (fd < 0) return -1;
    defer _ = close(fd);
    return lseek(fd, 0, seek_end);
}

// Waits until the process writes output or settles, so startup failures surface before we report recording.
fn confirmStarted(pid: c_int, output: [*:0]const u8) bool {
    var elapsed: u32 = 0;
    while (elapsed < 1500) : (elapsed += 50) {
        var status: c_int = 0;
        if (waitpid(pid, &status, wnohang) == pid) return false;
        if (elapsed >= 300 and fileSize(output) > 0) return true;
        _ = usleep(50_000);
    }
    return true;
}

fn stopProcess(pid: c_int, signal: c_int) bool {
    if (pid <= 0) return true;
    _ = kill(pid, signal);
    return wait(pid);
}

fn logTail(path: [*:0]const u8, destination: [*]u8, capacity: usize, fallback: []const u8) void {
    var buffer: [4096]u8 = undefined;
    const fd = open(path, o_rdonly);
    if (fd < 0) return copyOut(destination, capacity, fallback);
    defer _ = close(fd);
    const size = lseek(fd, 0, seek_end);
    const start: i64 = if (size > buffer.len) size - buffer.len else 0;
    _ = lseek(fd, start, 0);
    const count = read(fd, &buffer, buffer.len);
    if (count <= 0) return copyOut(destination, capacity, fallback);
    const text = std.mem.trim(u8, buffer[0..@intCast(count)], " \r\n\t");
    const line_start = if (std.mem.lastIndexOfScalar(u8, text, '\n')) |index| index + 1 else 0;
    const line = text[line_start..];
    if (line.len == 0) return copyOut(destination, capacity, fallback);
    const message = std.fmt.allocPrint(allocator, "{s}: {s}", .{ fallback, line }) catch return copyOut(destination, capacity, fallback);
    defer allocator.free(message);
    copyOut(destination, capacity, message);
}

const WindowRect = struct {
    x: i64,
    y: i64,
    width: i64,
    height: i64,
    layer: u8,
    order: i64,

    fn lessThan(_: void, left: WindowRect, right: WindowRect) bool {
        if (left.layer != right.layer) return left.layer < right.layer;
        return left.order < right.order;
    }
};

fn jsonInt(value: ?std.json.Value) ?i64 {
    const actual = value orelse return null;
    return switch (actual) {
        .integer => |number| number,
        .float => |number| @intFromFloat(number),
        else => null,
    };
}

fn jsonBool(value: ?std.json.Value) bool {
    const actual = value orelse return false;
    return switch (actual) {
        .bool => |flag| flag,
        .integer => |number| number != 0,
        else => false,
    };
}

fn jsonObject(value: ?std.json.Value) ?std.json.ObjectMap {
    const actual = value orelse return null;
    return if (actual == .object) actual.object else null;
}

fn jsonArray(value: ?std.json.Value) ?[]std.json.Value {
    const actual = value orelse return null;
    return if (actual == .array) actual.array.items else null;
}

fn hyprlandWindows(clients_json: []const u8, monitors_json: []const u8, output: *std.ArrayList(WindowRect)) !void {
    const monitors = try std.json.parseFromSlice(std.json.Value, allocator, monitors_json, .{});
    defer monitors.deinit();
    var visible: std.ArrayList(i64) = .empty;
    defer visible.deinit(allocator);
    for (jsonArray(monitors.value) orelse return error.InvalidJson) |monitor| {
        const fields = jsonObject(monitor) orelse continue;
        for ([_][]const u8{ "activeWorkspace", "specialWorkspace" }) |key| {
            const workspace = jsonObject(fields.get(key)) orelse continue;
            if (jsonInt(workspace.get("id"))) |id| if (id != 0) try visible.append(allocator, id);
        }
    }

    const clients = try std.json.parseFromSlice(std.json.Value, allocator, clients_json, .{});
    defer clients.deinit();
    for (jsonArray(clients.value) orelse return error.InvalidJson) |client| {
        const fields = jsonObject(client) orelse continue;
        if (!jsonBool(fields.get("mapped")) or jsonBool(fields.get("hidden"))) continue;
        const workspace = jsonObject(fields.get("workspace")) orelse continue;
        const workspace_id = jsonInt(workspace.get("id")) orelse continue;
        if (std.mem.indexOfScalar(i64, visible.items, workspace_id) == null) continue;
        const at = jsonArray(fields.get("at")) orelse continue;
        const size = jsonArray(fields.get("size")) orelse continue;
        if (at.len < 2 or size.len < 2) continue;
        const layer: u8 = if (jsonBool(fields.get("fullscreen"))) 0 else if (jsonBool(fields.get("pinned"))) 1 else if (jsonBool(fields.get("floating"))) 2 else 3;
        try output.append(allocator, .{
            .x = jsonInt(at[0]) orelse continue,
            .y = jsonInt(at[1]) orelse continue,
            .width = jsonInt(size[0]) orelse continue,
            .height = jsonInt(size[1]) orelse continue,
            .layer = layer,
            .order = jsonInt(fields.get("focusHistoryID")) orelse 0,
        });
    }
}

fn swayCollect(node: std.json.Value, floating: bool, order: *i64, output: *std.ArrayList(WindowRect)) !void {
    const fields = jsonObject(node) orelse return;
    const children = jsonArray(fields.get("nodes")) orelse &.{};
    const floating_children = jsonArray(fields.get("floating_nodes")) orelse &.{};
    const is_view = children.len == 0 and floating_children.len == 0 and fields.get("pid") != null;
    if (is_view and jsonBool(fields.get("visible"))) {
        const rect = jsonObject(fields.get("rect")) orelse return;
        order.* += 1;
        try output.append(allocator, .{
            .x = jsonInt(rect.get("x")) orelse return,
            .y = jsonInt(rect.get("y")) orelse return,
            .width = jsonInt(rect.get("width")) orelse return,
            .height = jsonInt(rect.get("height")) orelse return,
            .layer = if (jsonBool(fields.get("fullscreen_mode"))) 0 else if (floating) 2 else 3,
            .order = if (jsonBool(fields.get("focused"))) -1 else order.*,
        });
    }
    for (floating_children) |child| try swayCollect(child, true, order, output);
    for (children) |child| try swayCollect(child, floating, order, output);
}

fn swayWindows(tree_json: []const u8, output: *std.ArrayList(WindowRect)) !void {
    const tree = try std.json.parseFromSlice(std.json.Value, allocator, tree_json, .{});
    defer tree.deinit();
    var order: i64 = 0;
    try swayCollect(tree.value, false, &order, output);
}

fn formatWindows(windows: []WindowRect, destination: [*]u8, capacity: usize) void {
    std.mem.sort(WindowRect, windows, {}, WindowRect.lessThan);
    var used: usize = 0;
    for (windows) |window| {
        if (window.width <= 0 or window.height <= 0) continue;
        var line_buffer: [96]u8 = undefined;
        const line = std.fmt.bufPrint(&line_buffer, "{d} {d} {d} {d}\n", .{ window.x, window.y, window.width, window.height }) catch continue;
        if (used + line.len + 1 > capacity) break;
        @memcpy(destination[used .. used + line.len], line);
        used += line.len;
    }
    if (capacity > 0) destination[used] = 0;
}

export fn snipshot_freeze(output_name: [*:0]const u8, path: [*]u8, path_capacity: usize, errbuf: [*]u8, error_capacity: usize) c_int {
    const runtime = runtimeDirectory() catch return fail(errbuf, error_capacity, "Could not create the runtime folder");
    defer allocator.free(runtime);
    const name = std.mem.span(output_name);
    const destination = z("{s}/freeze-{s}.ppm", .{ runtime, if (name.len > 0) name else "all" }) catch
        return fail(errbuf, error_capacity, "Out of memory");
    defer allocator.free(destination);
    const ok = if (name.len > 0)
        run(&.{ "grim", "-t", "ppm", "-o", output_name, destination })
    else
        run(&.{ "grim", "-t", "ppm", destination });
    if (!ok) return fail(errbuf, error_capacity, "grim could not capture the screen. Is wlr-screencopy available?");
    copyOut(path, path_capacity, destination);
    return 0;
}

export fn snipshot_windows(rects: [*]u8, capacity: usize, errbuf: [*]u8, error_capacity: usize) c_int {
    var windows: std.ArrayList(WindowRect) = .empty;
    defer windows.deinit(allocator);
    if (getenv("HYPRLAND_INSTANCE_SIGNATURE") != null) {
        const clients = runCapture(&.{ "hyprctl", "-j", "clients" }) orelse return fail(errbuf, error_capacity, "hyprctl clients failed");
        defer allocator.free(clients);
        const monitors = runCapture(&.{ "hyprctl", "-j", "monitors" }) orelse return fail(errbuf, error_capacity, "hyprctl monitors failed");
        defer allocator.free(monitors);
        hyprlandWindows(clients, monitors, &windows) catch return fail(errbuf, error_capacity, "Could not read Hyprland windows");
    } else if (getenv("SWAYSOCK") != null) {
        const tree = runCapture(&.{ "swaymsg", "-r", "-t", "get_tree" }) orelse return fail(errbuf, error_capacity, "swaymsg get_tree failed");
        defer allocator.free(tree);
        swayWindows(tree, &windows) catch return fail(errbuf, error_capacity, "Could not read sway windows");
    } else {
        copyOut(errbuf, error_capacity, "Window snips are not supported on this desktop yet");
        return @intFromEnum(Result.unsupported);
    }
    formatWindows(windows.items, rects, capacity);
    return 0;
}

export fn snipshot_output_path(kind: c_int, directory: ?[*:0]const u8, extension: [*:0]const u8, path: [*]u8, path_capacity: usize, errbuf: [*]u8, error_capacity: usize) c_int {
    const destination = outputPath(@enumFromInt(kind), directory, std.mem.span(extension)) catch
        return fail(errbuf, error_capacity, "Could not create the output folder");
    defer allocator.free(destination);
    copyOut(path, path_capacity, destination);
    return 0;
}

export fn snipshot_temp_path(name: [*:0]const u8, path: [*]u8, path_capacity: usize) c_int {
    const runtime = runtimeDirectory() catch return @intFromEnum(Result.failed);
    defer allocator.free(runtime);
    const destination = z("{s}/{s}", .{ runtime, std.mem.span(name) }) catch return @intFromEnum(Result.failed);
    defer allocator.free(destination);
    copyOut(path, path_capacity, destination);
    return 0;
}

export fn snipshot_ocr(image: [*:0]const u8, languages: [*:0]const u8, text: [*]u8, text_capacity: usize, errbuf: [*]u8, error_capacity: usize) c_int {
    const langs = std.mem.span(languages);
    const output = if (langs.len > 0)
        runCapture(&.{ "tesseract", image, "stdout", "-l", languages })
    else
        runCapture(&.{ "tesseract", image, "stdout" });
    const recognized = output orelse return fail(errbuf, error_capacity, "Text recognition failed. Is tesseract installed with that language?");
    defer allocator.free(recognized);
    copyOut(text, text_capacity, std.mem.trim(u8, recognized, " \r\n\t\x0c"));
    return 0;
}

export fn snipshot_ocr_languages(output: [*]u8, capacity: usize) c_int {
    const listing = runCapture(&.{ "tesseract", "--list-langs" }) orelse {
        copyOut(output, capacity, "");
        return @intFromEnum(Result.failed);
    };
    defer allocator.free(listing);
    var languages: std.ArrayList(u8) = .empty;
    defer languages.deinit(allocator);
    var lines = std.mem.tokenizeAny(u8, listing, "\r\n");
    _ = lines.next();
    while (lines.next()) |line| {
        const language = std.mem.trim(u8, line, " \t");
        if (language.len == 0 or std.mem.eql(u8, language, "osd")) continue;
        languages.appendSlice(allocator, language) catch break;
        languages.append(allocator, '\n') catch break;
    }
    copyOut(output, capacity, languages.items);
    return 0;
}

export fn snipshot_copy_file(path: [*:0]const u8, mime: [*:0]const u8) c_int {
    if (!findInPath("wl-copy")) return @intFromEnum(Result.unsupported);
    const pid = spawn(.{ .argv = &.{ "wl-copy", "--type", mime }, .stdin_path = path }) orelse return @intFromEnum(Result.failed);
    return if (wait(pid)) 0 else @intFromEnum(Result.failed);
}

export fn snipshot_copy_text(text: [*:0]const u8) c_int {
    if (!findInPath("wl-copy")) return @intFromEnum(Result.unsupported);
    var descriptors: [2]c_int = undefined;
    if (pipe2(&descriptors, o_cloexec) != 0) return @intFromEnum(Result.failed);
    const pid = spawn(.{ .argv = &.{ "wl-copy", "--type", "text/plain;charset=utf-8" }, .stdin_fd = descriptors[0] }) orelse {
        _ = close(descriptors[0]);
        _ = close(descriptors[1]);
        return @intFromEnum(Result.failed);
    };
    _ = close(descriptors[0]);
    var remaining = std.mem.span(text);
    while (remaining.len > 0) {
        const count = write(descriptors[1], remaining.ptr, remaining.len);
        if (count <= 0) break;
        remaining = remaining[@intCast(count)..];
    }
    _ = close(descriptors[1]);
    return if (wait(pid)) 0 else @intFromEnum(Result.failed);
}

export fn snipshot_float_window(title: [*:0]const u8, width: c_int, height: c_int) c_int {
    const name = std.mem.span(title);
    for (name) |character| if (character == '\'' or character == '"' or character == '\\') return @intFromEnum(Result.failed);
    if (getenv("HYPRLAND_INSTANCE_SIGNATURE") != null) {
        const script = z("local title = '{s}'; for _, w in ipairs(hl.get_windows({{ title = title }})) do " ++
            "if w.title == title then hl.dispatch(hl.dsp.window.float({{ action = 'set', window = w }})); " ++
            "hl.dispatch(hl.dsp.window.resize({{ window = w, x = {d}, y = {d}, relative = false }})); " ++
            "hl.dispatch(hl.dsp.window.center({{ window = w }})); end end", .{ name, width, height }) catch return @intFromEnum(Result.failed);
        defer allocator.free(script);
        const output = runCapture(&.{ "hyprctl", "eval", script }) orelse return @intFromEnum(Result.failed);
        allocator.free(output);
        return 0;
    }
    if (getenv("SWAYSOCK") != null) {
        const command = z("[title=\"^{s}$\"] floating enable, resize set {d} {d}, move position center", .{ name, width, height }) catch return @intFromEnum(Result.failed);
        defer allocator.free(command);
        return if (run(&.{ "swaymsg", command })) 0 else @intFromEnum(Result.failed);
    }
    return @intFromEnum(Result.unsupported);
}

export fn snipshot_backend_available(backend: c_int) c_int {
    return switch (@as(Backend, @enumFromInt(backend))) {
        .auto => @intFromBool(findInPath("gpu-screen-recorder") or findInPath("wf-recorder")),
        .gpu_screen_recorder => @intFromBool(findInPath("gpu-screen-recorder")),
        .wf_recorder => @intFromBool(findInPath("wf-recorder")),
    };
}

fn recorderLogPath() ?[:0]u8 {
    const runtime = runtimeDirectory() catch return null;
    defer allocator.free(runtime);
    return z("{s}/recorder.log", .{runtime}) catch null;
}

fn startGpuScreenRecorder(state: *Recording, errbuf: [*]u8, error_capacity: usize) bool {
    const region = z("{d}x{d}+{d}+{d}", .{ state.region.width, state.region.height, state.region.x, state.region.y }) catch return false;
    defer allocator.free(region);
    const framerate = z("{d}", .{state.framerate}) catch return false;
    defer allocator.free(framerate);
    const audio: ?[*:0]const u8 = if (state.microphone and state.system_audio)
        "default_output|default_input"
    else if (state.system_audio)
        "default_output"
    else if (state.microphone)
        "default_input"
    else
        null;
    const log = recorderLogPath() orelse return false;
    defer allocator.free(log);
    var argv: [20]?[*:0]const u8 = undefined;
    const base = [_]?[*:0]const u8{ "gpu-screen-recorder", "-w", "region", "-region", region, "-f", framerate, "-c", "mp4", "-ac", "aac", "-cursor", "yes", "-o", state.final_path };
    @memcpy(argv[0..base.len], &base);
    var count: usize = base.len;
    if (audio) |source| {
        argv[count] = "-a";
        argv[count + 1] = source;
        count += 2;
    }
    const pid = spawn(.{ .argv = argv[0..count], .log_path = log }) orelse {
        copyOut(errbuf, error_capacity, "Could not launch gpu-screen-recorder");
        return false;
    };
    if (!confirmStarted(pid, state.final_path)) {
        logTail(log, errbuf, error_capacity, "gpu-screen-recorder stopped");
        _ = unlink(state.final_path);
        return false;
    }
    state.recorder = pid;
    return true;
}

fn startWfSegment(state: *Recording, errbuf: [*]u8, error_capacity: usize) bool {
    const index = state.segments.items.len;
    const segment = z("{s}.part-{d:0>3}.mkv", .{ state.final_path, index }) catch return false;
    const geometry = z("{d},{d} {d}x{d}", .{ state.region.x, state.region.y, state.region.width, state.region.height }) catch {
        allocator.free(segment);
        return false;
    };
    defer allocator.free(geometry);
    const framerate = z("{d}", .{state.framerate}) catch {
        allocator.free(segment);
        return false;
    };
    defer allocator.free(framerate);
    const log = recorderLogPath() orelse {
        allocator.free(segment);
        return false;
    };
    defer allocator.free(log);

    var argv: [16]?[*:0]const u8 = undefined;
    const base = [_]?[*:0]const u8{ "wf-recorder", "-y", "-g", geometry, "-r", framerate, "-x", "yuv420p", "-f", segment };
    @memcpy(argv[0..base.len], &base);
    var count: usize = base.len;
    if (state.system_audio) {
        argv[count] = "--audio=@DEFAULT_MONITOR@";
        count += 1;
    } else if (state.microphone) {
        argv[count] = "--audio=@DEFAULT_SOURCE@";
        count += 1;
    }
    const pid = spawn(.{ .argv = argv[0..count], .log_path = log }) orelse {
        allocator.free(segment);
        copyOut(errbuf, error_capacity, "Could not launch wf-recorder");
        return false;
    };
    if (!confirmStarted(pid, segment)) {
        logTail(log, errbuf, error_capacity, "wf-recorder stopped");
        _ = unlink(segment);
        allocator.free(segment);
        return false;
    }
    state.segments.append(allocator, segment) catch {
        _ = stopProcess(pid, sigint);
        allocator.free(segment);
        return false;
    };
    state.recorder = pid;

    // wf-recorder takes one audio device, so the microphone is captured alongside when both are wanted.
    if (state.system_audio and state.microphone) {
        const mic = z("{s}.mic-{d:0>3}.mka", .{ state.final_path, index }) catch return true;
        const mic_pid = spawn(.{ .argv = &.{ "ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "pulse", "-i", "@DEFAULT_SOURCE@", "-c:a", "flac", mic }, .log_path = "/dev/null" }) orelse {
            allocator.free(mic);
            return true;
        };
        state.mic_segments.append(allocator, mic) catch {
            _ = stopProcess(mic_pid, sigint);
            allocator.free(mic);
            return true;
        };
        state.mic_recorder = mic_pid;
    }
    return true;
}

fn stopWfSegment(state: *Recording) bool {
    const mic_pid = state.mic_recorder;
    state.mic_recorder = -1;
    if (mic_pid > 0) {
        _ = kill(mic_pid, sigint);
        var status: c_int = 0;
        _ = waitpid(mic_pid, &status, 0);
    }
    const pid = state.recorder;
    state.recorder = -1;
    return stopProcess(pid, sigint);
}

fn writeConcatList(path: [:0]const u8, files: []const [:0]u8) bool {
    const fd = open(path, o_write_create_truncate, @as(c_uint, 0o600));
    if (fd < 0) return false;
    defer _ = close(fd);
    for (files) |file| {
        var line: std.ArrayList(u8) = .empty;
        defer line.deinit(allocator);
        line.appendSlice(allocator, "file '") catch return false;
        for (file) |character| {
            if (character == '\'') {
                line.appendSlice(allocator, "'\\''") catch return false;
            } else {
                line.append(allocator, character) catch return false;
            }
        }
        line.appendSlice(allocator, "'\n") catch return false;
        if (write(fd, line.items.ptr, line.items.len) != @as(isize, @intCast(line.items.len))) return false;
    }
    return true;
}

fn concat(files: []const [:0]u8, destination: [:0]const u8) bool {
    const list = z("{s}.list", .{destination}) catch return false;
    defer allocator.free(list);
    defer _ = unlink(list);
    if (!writeConcatList(list, files)) return false;
    return run(&.{ "ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", list, "-c", "copy", destination });
}

fn finishWfRecording(state: *Recording, errbuf: [*]u8, error_capacity: usize) bool {
    const joined = z("{s}.joined.mkv", .{state.final_path}) catch return false;
    defer allocator.free(joined);
    defer _ = unlink(joined);
    if (!concat(state.segments.items, joined)) {
        copyOut(errbuf, error_capacity, "Could not join the recording. The segments were kept.");
        return false;
    }
    const final = state.final_path;
    var ok: bool = undefined;
    if (state.mic_segments.items.len > 0) {
        const mic = z("{s}.mic.mka", .{final}) catch return false;
        defer allocator.free(mic);
        defer _ = unlink(mic);
        if (!concat(state.mic_segments.items, mic)) {
            copyOut(errbuf, error_capacity, "Could not join the microphone audio. The segments were kept.");
            return false;
        }
        ok = run(&.{ "ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", joined, "-i", mic, "-filter_complex", "[0:a][1:a]amix=inputs=2:duration=first:normalize=0[a]", "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-movflags", "+faststart", final });
    } else if (state.system_audio or state.microphone) {
        ok = run(&.{ "ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", joined, "-c:v", "copy", "-c:a", "aac", "-movflags", "+faststart", final });
    } else {
        ok = run(&.{ "ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", joined, "-c", "copy", "-movflags", "+faststart", final });
    }
    if (!ok) {
        copyOut(errbuf, error_capacity, "Could not write the final video. The segments were kept.");
        return false;
    }
    return true;
}

fn releaseRecording(delete_parts: bool) void {
    var state = recording orelse return;
    for (state.segments.items) |segment| {
        if (delete_parts) _ = unlink(segment);
        allocator.free(segment);
    }
    for (state.mic_segments.items) |segment| {
        if (delete_parts) _ = unlink(segment);
        allocator.free(segment);
    }
    state.segments.deinit(allocator);
    state.mic_segments.deinit(allocator);
    allocator.free(state.final_path);
    recording = null;
}

export fn snipshot_record_start(options: *const SnipShotRecordOptions, path: [*]u8, path_capacity: usize, used_backend: *c_int, errbuf: [*]u8, error_capacity: usize) c_int {
    if (recording != null) return fail(errbuf, error_capacity, "A recording is already running");
    if (options.region.width <= 0 or options.region.height <= 0) return fail(errbuf, error_capacity, "The recording region is empty");
    const requested: Backend = @enumFromInt(options.backend);
    const candidates: []const Backend = switch (requested) {
        .auto => &.{ .gpu_screen_recorder, .wf_recorder },
        .gpu_screen_recorder => &.{.gpu_screen_recorder},
        .wf_recorder => &.{.wf_recorder},
    };
    // Encoders need even dimensions.
    var region = options.region;
    region.width -= @mod(region.width, 2);
    region.height -= @mod(region.height, 2);

    var tried_any = false;
    for (candidates) |backend| {
        const tool = if (backend == .gpu_screen_recorder) "gpu-screen-recorder" else "wf-recorder";
        if (!findInPath(tool)) continue;
        tried_any = true;
        const final_path = outputPath(.recording, options.directory, "mp4") catch
            return fail(errbuf, error_capacity, "Could not create the video folder");
        recording = .{
            .backend = backend,
            .final_path = final_path,
            .region = region,
            .microphone = options.microphone != 0,
            .system_audio = options.system_audio != 0,
            .framerate = if (options.framerate > 0) options.framerate else 60,
        };
        const started = switch (backend) {
            .gpu_screen_recorder => startGpuScreenRecorder(&recording.?, errbuf, error_capacity),
            else => startWfSegment(&recording.?, errbuf, error_capacity),
        };
        if (started) {
            copyOut(path, path_capacity, final_path);
            used_backend.* = @intFromEnum(backend);
            return 0;
        }
        releaseRecording(true);
    }
    if (!tried_any) return fail(errbuf, error_capacity, "Install gpu-screen-recorder or wf-recorder to record");
    return @intFromEnum(Result.failed);
}

export fn snipshot_record_pause(pause: c_int, errbuf: [*]u8, error_capacity: usize) c_int {
    const state = if (recording) |*active| active else return fail(errbuf, error_capacity, "No recording is running");
    const should_pause = pause != 0;
    if (should_pause == state.paused) return 0;
    switch (state.backend) {
        .gpu_screen_recorder => {
            if (kill(state.recorder, sigusr2) != 0) return fail(errbuf, error_capacity, "gpu-screen-recorder is no longer running");
        },
        else => {
            if (should_pause) {
                if (!stopWfSegment(state)) return fail(errbuf, error_capacity, "wf-recorder did not finish the segment cleanly");
            } else if (!startWfSegment(state, errbuf, error_capacity)) {
                return @intFromEnum(Result.failed);
            }
        },
    }
    state.paused = should_pause;
    return 0;
}

export fn snipshot_record_stop(errbuf: [*]u8, error_capacity: usize) c_int {
    const state = if (recording) |*active| active else return fail(errbuf, error_capacity, "No recording is running");
    switch (state.backend) {
        .gpu_screen_recorder => {
            const pid = state.recorder;
            state.recorder = -1;
            if (!stopProcess(pid, sigint) or fileSize(state.final_path) <= 0) {
                releaseRecording(false);
                return fail(errbuf, error_capacity, "gpu-screen-recorder did not finish cleanly");
            }
        },
        else => {
            if (state.recorder > 0 and !stopWfSegment(state)) {
                releaseRecording(false);
                return fail(errbuf, error_capacity, "wf-recorder did not finish cleanly. The segments were kept.");
            }
            if (!finishWfRecording(state, errbuf, error_capacity)) {
                releaseRecording(false);
                return @intFromEnum(Result.failed);
            }
        },
    }
    releaseRecording(true);
    return 0;
}

export fn snipshot_record_abort() c_int {
    const state = if (recording) |*active| active else return 0;
    if (state.backend == .gpu_screen_recorder) {
        _ = stopProcess(state.recorder, sigint);
        _ = unlink(state.final_path);
    } else {
        _ = stopWfSegment(state);
    }
    releaseRecording(true);
    return 0;
}

test "hyprland windows keep visible workspaces in stacking order" {
    const monitors =
        \\[{"activeWorkspace":{"id":1},"specialWorkspace":{"name":""}},{"activeWorkspace":{"id":4},"specialWorkspace":{"id":-98}}]
    ;
    const clients =
        \\[{"at":[0,0],"size":[100,50],"workspace":{"id":1},"mapped":true,"hidden":false,"floating":false,"pinned":false,"fullscreen":0,"focusHistoryID":0},
        \\ {"at":[10,10],"size":[30,30],"workspace":{"id":1},"mapped":true,"hidden":false,"floating":true,"pinned":false,"fullscreen":0,"focusHistoryID":2},
        \\ {"at":[-1068,-409],"size":[1056,615],"workspace":{"id":4},"mapped":true,"hidden":false,"floating":false,"pinned":false,"fullscreen":0,"focusHistoryID":3},
        \\ {"at":[5,5],"size":[5,5],"workspace":{"id":6},"mapped":true,"hidden":false,"floating":false,"pinned":false,"fullscreen":0,"focusHistoryID":1},
        \\ {"at":[7,7],"size":[5,5],"workspace":{"id":-98},"mapped":true,"hidden":true,"floating":false,"pinned":false,"fullscreen":0,"focusHistoryID":4}]
    ;
    var windows: std.ArrayList(WindowRect) = .empty;
    defer windows.deinit(allocator);
    try hyprlandWindows(clients, monitors, &windows);
    var text: [256]u8 = undefined;
    formatWindows(windows.items, &text, text.len);
    try std.testing.expectEqualStrings("10 10 30 30\n0 0 100 50\n-1068 -409 1056 615\n", std.mem.sliceTo(&text, 0));
}

test "sway windows include floating views first" {
    const tree =
        \\{"type":"root","nodes":[{"type":"output","nodes":[{"type":"workspace","nodes":[
        \\  {"type":"con","pid":10,"visible":true,"focused":false,"rect":{"x":0,"y":0,"width":640,"height":480},"nodes":[],"floating_nodes":[]},
        \\  {"type":"con","pid":11,"visible":false,"rect":{"x":640,"y":0,"width":640,"height":480},"nodes":[],"floating_nodes":[]}
        \\ ],"floating_nodes":[{"type":"floating_con","pid":12,"visible":true,"rect":{"x":100,"y":100,"width":200,"height":100},"nodes":[],"floating_nodes":[]}]}]}]}
    ;
    var windows: std.ArrayList(WindowRect) = .empty;
    defer windows.deinit(allocator);
    try swayWindows(tree, &windows);
    var text: [256]u8 = undefined;
    formatWindows(windows.items, &text, text.len);
    try std.testing.expectEqualStrings("100 100 200 100\n0 0 640 480\n", std.mem.sliceTo(&text, 0));
}

test "concat list escapes quotes" {
    const runtime = try runtimeDirectory();
    defer allocator.free(runtime);
    const list = try z("{s}/test-concat.list", .{runtime});
    defer allocator.free(list);
    defer _ = unlink(list);
    var files = [_][:0]u8{try z("/tmp/it's.mkv", .{})};
    defer allocator.free(files[0]);
    try std.testing.expect(writeConcatList(list, &files));
    const fd = open(list, o_rdonly);
    defer _ = close(fd);
    var buffer: [64]u8 = undefined;
    const count = read(fd, &buffer, buffer.len);
    try std.testing.expectEqualStrings("file '/tmp/it'\\''s.mkv'\n", buffer[0..@intCast(count)]);
}

comptime {
    if (builtin.os.tag != .linux) @compileError("SnipShot's core currently targets Linux");
}
