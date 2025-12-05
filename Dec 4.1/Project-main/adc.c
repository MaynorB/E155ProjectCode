#include "adc.h"
#include "stm32l4xx.h"

// Local delay (same as original)
static void delay_ms(uint32_t ms) {
    for (uint32_t i = 0; i < ms * 8000; i++) {
        __NOP();
    }
}

void ADC_Init(void) {

    // Enable GPIOA
    RCC->AHB2ENR |= RCC_AHB2ENR_GPIOAEN;

    // Configure PA0 + PA1 as analog (ADC input)
    GPIOA->MODER |= (GPIO_MODER_MODER0 | GPIO_MODER_MODER1);

    // Enable ADC clock
    RCC->AHB2ENR |= RCC_AHB2ENR_ADCEN;

    // Set ADC clock mode
    ADC1_COMMON->CCR &= ~ADC_CCR_CKMODE;
    ADC1_COMMON->CCR |= ADC_CCR_CKMODE_0;

    // Exit deep power-down, enable regulator
    ADC1->CR &= ~ADC_CR_DEEPPWD;
    ADC1->CR |= ADC_CR_ADVREGEN;
    delay_ms(1);

    // Calibration
    ADC1->CR |= ADC_CR_ADCAL;
    while (ADC1->CR & ADC_CR_ADCAL);

    // Enable ADC
    ADC1->CR |= ADC_CR_ADEN;
    while (!(ADC1->ISR & ADC_ISR_ADRDY));

    // Resolution = 8-bit
    ADC1->CFGR = ADC_CFGR_RES_1;

    // Single conversion mode
    ADC1->CFGR &= ~ADC_CFGR_CONT;
}

uint8_t Read_ADC_Channel(uint8_t channel) {

    // Select channel
    ADC1->SQR1 = (channel << ADC_SQR1_SQ1_Pos);

    // Start conversion
    ADC1->CR |= ADC_CR_ADSTART;

    // Wait until done
    while (!(ADC1->ISR & ADC_ISR_EOC));

    // Return 8-bit result
    return (uint8_t)ADC1->DR;
}
