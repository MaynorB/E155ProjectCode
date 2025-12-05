#include "timer.h"
#include "main.h"
#include "stm32l432xx.h"

// These globals live in main.c, but are declared in main.h
extern volatile uint16_t f_read_counter;
extern volatile int f_read_ready_flag;
extern volatile uint16_t adc_counter;

extern uint8_t scale_1p5_and_clamp(uint8_t v);
extern uint8_t Read_ADC_Channel(uint8_t channel);


// -----------------------------------------------------------------------------
// TIM2 Initialization (Default)
// -----------------------------------------------------------------------------
void TIM2_Init_Default(void) {
    RCC->APB1ENR1 |= RCC_APB1ENR1_TIM2EN;

    TIM2->PSC = 0;
    TIM2->ARR = 832;                 // Initial ARR

    TIM2->DIER |= TIM_DIER_UIE;      // Update interrupt enable

    NVIC_SetPriority(TIM2_IRQn, 2);
    NVIC_EnableIRQ(TIM2_IRQn);

    TIM2->CR1 |= TIM_CR1_CEN;        // Start timer
}


// -----------------------------------------------------------------------------
// TIM2 Interrupt Handler
// -----------------------------------------------------------------------------
void TIM2_IRQHandler(void) {

    if (TIM2->SR & TIM_SR_UIF) {
        TIM2->SR &= ~TIM_SR_UIF;

        // Toggle PB0 (square wave)
        GPIOB->ODR ^= GPIO_ODR_OD0;

        // WAV buffer counter
        f_read_counter++;
        if (f_read_counter >= 512) {
            f_read_counter = 0;
            f_read_ready_flag = 1;
        }

        // ADC-based speed control
        adc_counter++;
        if (adc_counter >= 4800) {
            adc_counter = 0;

            uint8_t pot_val = Read_ADC_Channel(ADC_PIN_SPEED);
            uint8_t pot_scaled = scale_1p5_and_clamp(pot_val);

            uint32_t new_arr = 455 + ((uint32_t)pot_scaled * 772) / 255;

            // Dead-zone correction
            if (new_arr < 855 && new_arr > 811)
                new_arr = 832;

            TIM2->ARR = new_arr;
        }
    }
}
