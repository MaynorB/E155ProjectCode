#include "diskio.h"
#include "SD_lowlevel.h"

#define DEV_SD 0

DSTATUS disk_status(BYTE pdrv) {
    return (pdrv == DEV_SD) ? 0 : STA_NOINIT;
}

DSTATUS disk_initialize(BYTE pdrv) {
    if (pdrv != DEV_SD)
        return STA_NOINIT;
    return (SD_Init() == SD_OK) ? 0 : STA_NOINIT;
}

DRESULT disk_read(BYTE pdrv, BYTE* buff, LBA_t sector, UINT count) {
    if (pdrv != DEV_SD)
        return RES_PARERR;

    while (count--) {
        if (SD_ReadBlock(sector++, buff) != SD_OK)
            return RES_ERROR;
        buff += 512;
    }
    return RES_OK;
}

DRESULT disk_write(BYTE pdrv, const BYTE* buff, LBA_t sector, UINT count) {
    if (pdrv != DEV_SD)
        return RES_PARERR;

    while (count--) {
        if (SD_WriteBlock(sector++, buff) != SD_OK)
            return RES_ERROR;
        buff += 512;
    }
    return RES_OK;
}

DRESULT disk_ioctl(BYTE pdrv, BYTE cmd, void* buff) {
    if (pdrv != DEV_SD)
        return RES_PARERR;

    switch (cmd) {
        case CTRL_SYNC:
            return RES_OK;
        case GET_SECTOR_SIZE:
            *(WORD*)buff = 512;
            return RES_OK;
        case GET_BLOCK_SIZE:
            *(DWORD*)buff = 1;
            return RES_OK;
        case GET_SECTOR_COUNT:
            *(DWORD*)buff = 32768000U; // for 16GB card
            return RES_OK;
    }
    return RES_PARERR;
}
