#ifndef WAV_H
#define WAV_H

#include "ff.h"
#include "main.h"   // For MAX_WAV_FILES and global declarations

// API
void scan_wav_files(void);
int open_next_wav_file(void);

#endif
