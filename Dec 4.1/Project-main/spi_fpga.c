#include "spi_fpga.h"
#include "stm32l432xx.h"
#include "main.h"

// -----------------------------------------------------------------------------
// Configure SPI1 for streaming audio + sensor data to FPGA
// -----------------------------------------------------------------------------
void initSPI1_FPGA(void) {

    // Enable GPIOA clock
    RCC->AHB2ENR |= RCC_AHB2ENR_GPIOAEN;

    // PA5 (SCK), PA7 (MOSI) → AF mode
    GPIOA->MODER &= ~(GPIO_MODER_MODER5 | GPIO_MODER_MODER7);
    GPIOA->MODER |=  (GPIO_MODER_MODER5_1 | GPIO_MODER_MODER7_1);

    // High speed
    GPIOA->OSPEEDR |= (GPIO_OSPEEDR_OSPEED5 | GPIO_OSPEEDR_OSPEED7);

    // AF5 (SPI1)
    GPIOA->AFR[0] &= ~((0xF << 20) | (0xF << 28));
    GPIOA->AFR[0] |=  ((5 << 20) | (5 << 28));

    // Enable SPI1 clock
    RCC->APB2ENR |= RCC_APB2ENR_SPI1EN;

    // Configure SPI1
    SPI1->CR1 = SPI_CR1_MSTR | SPI_CR1_SSM | SPI_CR1_SSI | SPI_CR1_BR_2;  // slow baud
    SPI1->CR2 = (0x7 << SPI_CR2_DS_Pos) | SPI_CR2_FRXTH;  // 8-bit

    SPI1->CR1 |= SPI_CR1_SPE;   // enable SPI
}


// -----------------------------------------------------------------------------
// Send len bytes to FPGA using SPI1 + external chip select
// -----------------------------------------------------------------------------
void send_spi_data(uint8_t *buf, uint16_t len, uint32_t cs_pin_mask) {

    // CS low
    GPIOA->ODR &= ~cs_pin_mask;

    // Transmit
    for (uint16_t i = 0; i < len; i++) {

        while (!(SPI1->SR & SPI_SR_TXE));
        *(volatile uint8_t *)&SPI1->DR = buf[i];

        while (!(SPI1->SR & SPI_SR_RXNE));
        (void)*(volatile uint8_t *)&SPI1->DR;
    }

    // CS high
    GPIOA->ODR |= cs_pin_mask;
}
