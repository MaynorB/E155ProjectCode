#ifndef STM32L432KC_SPI_H
#define STM32L432KC_SPI_H

#include <stdint.h>

// SD Card Chip Select pin
#define SD_CS_PIN PA11

// Baud-rate presets for cleaner code
typedef enum {
    SPI_BR_2   = 0b000,   // fPCLK / 2
    SPI_BR_4   = 0b001,
    SPI_BR_8   = 0b010,
    SPI_BR_16  = 0b011,
    SPI_BR_32  = 0b100,
    SPI_BR_64  = 0b101,
    SPI_BR_128 = 0b110,
    SPI_BR_256 = 0b111    // fPCLK / 256
} SPI_BaudRate;

// SPI3 interface (SD card)
void initSPI3(SPI_BaudRate br, int cpol, int cpha);
uint8_t spi3_transfer(uint8_t byte);

// SD helper wrappers
void SD_Select(void);
void SD_Deselect(void);
uint8_t SD_SPI_Transmit(uint8_t d);
uint8_t SD_SPI_Receive(void);

#endif
