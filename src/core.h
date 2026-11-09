#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

enum SnipShotResult { SNIPSHOT_OK = 0, SNIPSHOT_CANCELLED = 1, SNIPSHOT_FAILED = 2, SNIPSHOT_UNSUPPORTED = 3 };
enum SnipShotBackend { SNIPSHOT_BACKEND_AUTO = 0, SNIPSHOT_BACKEND_GPU_SCREEN_RECORDER = 1, SNIPSHOT_BACKEND_WF_RECORDER = 2 };
enum SnipShotKind { SNIPSHOT_KIND_SCREENSHOT = 0, SNIPSHOT_KIND_RECORDING = 1 };

typedef struct SnipShotRegion {
    int x;
    int y;
    int width;
    int height;
} SnipShotRegion;

typedef struct SnipShotRecordOptions {
    SnipShotRegion region;
    int backend;
    int microphone;
    int system_audio;
    int framerate;
    const char *directory;
} SnipShotRecordOptions;

int snipshot_freeze(const char *output_name, char *path, size_t path_capacity, char *error, size_t error_capacity);
int snipshot_windows(char *rects, size_t capacity, char *error, size_t error_capacity);
int snipshot_output_path(int kind, const char *directory, const char *extension, char *path, size_t path_capacity,
                         char *error, size_t error_capacity);
int snipshot_temp_path(const char *name, char *path, size_t path_capacity);
int snipshot_ocr(const char *image, const char *languages, char *text, size_t text_capacity, char *error,
                 size_t error_capacity);
int snipshot_ocr_languages(char *output, size_t capacity);
int snipshot_copy_file(const char *path, const char *mime);
int snipshot_copy_text(const char *text);
int snipshot_backend_available(int backend);
int snipshot_float_window(const char *title, int width, int height);
int snipshot_record_start(const SnipShotRecordOptions *options, char *path, size_t path_capacity, int *used_backend,
                          char *error, size_t error_capacity);
int snipshot_record_pause(int pause, char *error, size_t error_capacity);
int snipshot_record_stop(char *error, size_t error_capacity);
int snipshot_record_abort(void);

#ifdef __cplusplus
}
#endif
