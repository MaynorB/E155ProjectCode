#include "STM32L432KC_SPI.h"
#include "stm32l432xx.h"
#include "STM32L432KC_GPIO.h"

// Dummy byte
static const uint8_t DUMMY = 0xFF;

void initSPI3(SPI_BaudRate br, int cpol, int cpha) {

    // Enable GPIOB and GPIOA (for CS pin)
    RCC->AHB2ENR |= RCC_AHB2ENR_GPIOBEN | RCC_AHB2ENR_GPIOAEN;

    //--------------------------------------------------
    // Configure PB3 = SCK, PB4 = MISO, PB5 = MOSI
    //--------------------------------------------------
    GPIOB->MODER &= ~(GPIO_MODER_MODER3 | GPIO_MODER_MODER4 | GPIO_MODER_MODER5);
    GPIOB->MODER |=  (GPIO_MODER_MODER3_1 | GPIO_MODER_MODER4_1 | GPIO_MODER_MODER5_1); // AF mode

    // AF6 (SPI3)
    GPIOB->AFR[0] &= ~((0xF<<12)|(0xF<<16)|(0xF<<20));
    GPIOB->AFR[0] |=  ((6<<12)|(6<<16)|(6<<20));

    // High speed for SCK + MOSI
    GPIOB->OSPEEDR |= (GPIO_OSPEEDR_OSPEED3 | GPIO_OSPEEDR_OSPEED5);

   // Pull-up for PB4 (MISO) — PUPDR4 = 01 (pull-up)
GPIOB->PUPDR &= ~(0x3U << (4 * 2));   // clear PUPDR for PB4
GPIOB->PUPDR |=  (0x1U << (4 * 2));   // set pull-up (01)


    //--------------------------------------------------
    // Configure PA11 as CS (manual control)
    //--------------------------------------------------
    pinMode(SD_CS_PIN, GPIO_OUTPUT);
    digitalWrite(SD_CS_PIN, 1);

    //--------------------------------------------------
    // Enable SPI3 clock
    //--------------------------------------------------
    RCC->APB1ENR1 |= RCC_APB1ENR1_SPI3EN;

    //--------------------------------------------------
    // Configure SPI3
    //--------------------------------------------------
    SPI3->CR1 = 0;
    SPI3->CR1 |= (br << SPI_CR1_BR_Pos);

    if(cpol) SPI3->CR1 |= SPI_CR1_CPOL;
    if(cpha) SPI3->CR1 |= SPI_CR1_CPHA;

    SPI3->CR1 |=  SPI_CR1_MSTR | SPI_CR1_SSM | SPI_CR1_SSI;

    // 8-bit data size
    SPI3->CR2 = (7 << SPI_CR2_DS_Pos) | SPI_CR2_FRXTH;

    SPI3->CR1 |= SPI_CR1_SPE;
}

uint8_t spi3_transfer(uint8_t byte) {

    while(!(SPI3->SR & SPI_SR_TXE));
    *(volatile uint8_t*)&SPI3->DR = byte;

    while(!(SPI3->SR & SPI_SR_RXNE));
    return *(volatile uint8_t*)&SPI3->DR;
}

//--------------------------------------------------
// SD wrappers
//--------------------------------------------------

void SD_Select(void) {
    digitalWrite(SD_CS_PIN, 0);
}

void SD_Deselect(void) {
    digitalWrite(SD_CS_PIN, 1);
    spi3_transfer(DUMMY);
}

uint8_t SD_SPI_Transmit(uint8_t d) { return spi3_transfer(d); }
uint8_t SD_SPI_Receive(void)       { return spi3_transfer(DUMMY); }

