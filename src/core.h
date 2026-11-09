#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SnipShotRegion {
    int x;
    int y;
    int width;
    int height;
} SnipShotRegion;

int snipshot_capture(int extract_text, char *path, size_t path_capacity,
                     char *text, size_t text_capacity, char *error,
                     size_t error_capacity);
int snipshot_record_start(char *path, size_t path_capacity, SnipShotRegion *region,
                          char *error, size_t error_capacity);
int snipshot_record_pause(int pause, char *error, size_t error_capacity);
int snipshot_record_abort(char *error, size_t error_capacity);
int snipshot_record_stop(char *error, size_t error_capacity);

#ifdef __cplusplus
}
#endif
