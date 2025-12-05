#include "wav.h"
#include <string.h>

// These globals are declared in main.h, defined in main.c:
extern FATFS FatFs;
extern FIL file;
extern FRESULT fres;

extern BYTE audio_buffer[512];
extern UINT bytesRead;

extern char wav_files[MAX_WAV_FILES][32];
extern uint8_t wav_file_count;
extern int8_t current_file_index;


// -----------------------------------------------------------------------------
// Scan SD card root directory for .WAV files
// -----------------------------------------------------------------------------
void scan_wav_files(void) {
    DIR dir;
    FILINFO fno;

    wav_file_count = 0;

    if (f_opendir(&dir, "/") != FR_OK)
        return;

    for (;;) {
        if (f_readdir(&dir, &fno) != FR_OK || fno.fname[0] == 0)
            break;

        if (!(fno.fattrib & AM_DIR)) {
            char *ext = strrchr(fno.fname, '.');
            if (ext && (strcasecmp(ext, ".WAV") == 0)) {
                if (wav_file_count < MAX_WAV_FILES) {
                    strcpy(wav_files[wav_file_count], fno.fname);
                    wav_file_count++;
                }
            }
        }
    }

    f_closedir(&dir);
}


// -----------------------------------------------------------------------------
// Open next WAV file in the file list
// Reads header (44 bytes) and positions file for streaming
// -----------------------------------------------------------------------------
int open_next_wav_file(void) {
    if (wav_file_count == 0)
        return -1;

    current_file_index = (current_file_index + 1) % wav_file_count;

    FRESULT result = f_open(&file, wav_files[current_file_index], FA_READ);
    if (result != FR_OK)
        return -1;

    // Skip the WAV header (44 bytes)
    f_read(&file, audio_buffer, 44, &bytesRead);

    return 0;
}
