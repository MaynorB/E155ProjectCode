#ifndef SD_LOWLEVEL_H
#define SD_LOWLEVEL_H

#include <stdint.h>

#define SD_OK       0
#define SD_ERROR    1
#define SD_TIMEOUT  2

uint8_t SD_Init(void);
uint8_t SD_ReadBlock(uint32_t sector, uint8_t* buf);
uint8_t SD_WriteBlock(uint32_t sector, const uint8_t* buf);

#endif
