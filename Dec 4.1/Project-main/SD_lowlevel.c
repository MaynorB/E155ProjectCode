#include "SD_lowlevel.h"
#include "STM32L432KC_SPI.h"
#include <stdint.h>

// SD commands
#define CMD0    (0x40+0)
#define CMD8    (0x40+8)
#define CMD17   (0x40+17)
#define CMD24   (0x40+24)
#define CMD55   (0x40+55)
#define CMD58   (0x40+58)
#define ACMD41  (0x40+41)

#define TOKEN_START 0xFE

#define CARD_UNKNOWN 0
#define CARD_SD1     1
#define CARD_SD2     2
#define CARD_SDHC    3

static uint8_t cardType = CARD_UNKNOWN;

static uint8_t SD_SendCommand(uint8_t cmd, uint32_t arg, uint8_t crc);
static uint8_t SD_WaitReady(void);
static void SD_ClockOut(uint32_t clocks);

uint8_t SD_Init(void) {
    uint8_t r;
    uint8_t ocr[4];

    // Init SPI3 slow (fPCLK/256)
    initSPI3(SPI_BR_256, 0, 0);

    // Send 80 clocks with CS high
    SD_Deselect();
    SD_ClockOut(80);

    //----------------------------------------------
    // CMD0 — reset
    //----------------------------------------------
    if (SD_SendCommand(CMD0, 0, 0x95) != 1)
        return SD_ERROR;

    //----------------------------------------------
    // CMD8 — check SD2 / voltage range
    //----------------------------------------------
    r = SD_SendCommand(CMD8, 0x1AA, 0x87);

    if (r == 1) {   // SD v2
        for(int i=0;i<4;i++) ocr[i] = SD_SPI_Receive();

        if (ocr[2] != 0x01 || ocr[3] != 0xAA)
            return SD_ERROR; // invalid voltage

        //------------------------------------------
        // ACMD41 with HCS bit
        //------------------------------------------
        do {
            SD_SendCommand(CMD55,0,0x01);
            r = SD_SendCommand(ACMD41, 0x40000000, 0x01);
        } while (r != 0);

        //------------------------------------------
        // CMD58 — read OCR
        //------------------------------------------
        SD_SendCommand(CMD58,0,0x01);
        for(int i=0;i<4;i++) ocr[i] = SD_SPI_Receive();

        if (ocr[0] & 0x40)
            cardType = CARD_SDHC;
        else
            cardType = CARD_SD2;
    }
    else {
        //------------------------------------------
        // SD v1 or MMC
        //------------------------------------------
        do {
            SD_SendCommand(CMD55,0,0x01);
            r = SD_SendCommand(ACMD41,0,0x01);
        } while (r != 0);

        cardType = CARD_SD1;
    }

    SD_Deselect();
    SD_SPI_Receive();

    //----------------------------------------------
    // Now switch SPI to full speed (10 MHz)
    //----------------------------------------------
    initSPI3(SPI_BR_8, 0, 0);   // 80 MHz / 8 = 10 MHz

    return SD_OK;
}

uint8_t SD_ReadBlock(uint32_t sector, uint8_t* buf) {
    if (cardType != CARD_SDHC) sector *= 512;

    if (SD_SendCommand(CMD17, sector, 0x01) != 0) {
        SD_Deselect();
        return SD_ERROR;
    }

    uint16_t t = 0xFFFF;
    uint8_t token;

    do {
        token = SD_SPI_Receive();
    } while (token == 0xFF && --t);

    if (token != TOKEN_START)
        return SD_TIMEOUT;

    for (int i=0;i<512;i++)
        buf[i] = SD_SPI_Receive();

    SD_SPI_Receive(); // CRC
    SD_SPI_Receive();

    SD_Deselect();
    return SD_OK;
}

uint8_t SD_WriteBlock(uint32_t sector, const uint8_t* buf) {

    if (cardType != CARD_SDHC) sector *= 512;

    if (SD_SendCommand(CMD24, sector, 0x01) != 0) 
        return SD_ERROR;

    SD_SPI_Transmit(TOKEN_START);

    for (int i=0;i<512;i++)
        SD_SPI_Transmit(buf[i]);

    SD_SPI_Transmit(0xFF);
    SD_SPI_Transmit(0xFF);

    uint8_t resp = SD_SPI_Receive();
    if ((resp & 0x1F) != 0x05)
        return SD_ERROR;

    if (SD_WaitReady())
        return SD_TIMEOUT;

    SD_Deselect();
    return SD_OK;
}

//--------------------------------------------------

static uint8_t SD_SendCommand(uint8_t cmd, uint32_t arg, uint8_t crc) {

    SD_Deselect();
    SD_Select();

    SD_SPI_Transmit(cmd);
    SD_SPI_Transmit(arg>>24);
    SD_SPI_Transmit(arg>>16);
    SD_SPI_Transmit(arg>>8);
    SD_SPI_Transmit(arg);
    SD_SPI_Transmit(crc);

    uint8_t r;
    for(int i=0;i<10;i++) {
        r = SD_SPI_Receive();
        if (!(r & 0x80))
            break;
    }
    return r;
}

static uint8_t SD_WaitReady(void) {
    uint16_t t = 0xFFFF;
    while(--t) {
        if (SD_SPI_Receive() == 0xFF)
            return SD_OK;
    }
    return SD_TIMEOUT;
}

static void SD_ClockOut(uint32_t clocks) {
    for(uint32_t i=0;i<clocks;i++)
        SD_SPI_Receive();
}
