#include "main.h"
#include "adc.h"
#include "wav.h"
#include "timer.h"
#include "spi_fpga.h"

///////////////////////////////////////////////////////////////////////////////
// Global Variables
///////////////////////////////////////////////////////////////////////////////
FATFS FatFs;
FIL file;
FRESULT fres;
BYTE audio_buffer[512];
UINT bytesRead;

volatile uint16_t f_read_counter = 0;
volatile int f_read_ready_flag = 0;
volatile uint16_t adc_counter = 0;

char wav_files[MAX_WAV_FILES][32];
uint8_t wav_file_count = 0;
int8_t current_file_index = -1;

///////////////////////////////////////////////////////////////////////////////
// Delay
///////////////////////////////////////////////////////////////////////////////
void delay_ms(uint32_t ms) {
    for (uint32_t i = 0; i < ms * 8000; i++)
        __NOP();
}

///////////////////////////////////////////////////////////////////////////////
// Error blink
///////////////////////////////////////////////////////////////////////////////
void blink_error(uint8_t times) {
    printf("Critical Error Occurred! Code: %d\n", times);
}

///////////////////////////////////////////////////////////////////////////////
// ITM printf support
///////////////////////////////////////////////////////////////////////////////
int _write(int file, char *ptr, int len) {
    for (int i = 0; i < len; i++)
        ITM_SendChar((*ptr++));
    return len;
}

///////////////////////////////////////////////////////////////////////////////
// Button init
///////////////////////////////////////////////////////////////////////////////
void Button_Init(void) {
    RCC->AHB2ENR |= RCC_AHB2ENR_GPIOAEN;
    GPIOA->MODER &= ~(GPIO_MODER_MODER3);
    GPIOA->PUPDR &= ~(GPIO_PUPDR_PUPDR3);
    GPIOA->PUPDR |= GPIO_PUPDR_PUPDR3_1;
}

int check_button(void) {
    static uint8_t last_state = 0;
    static uint32_t cooldown_timer = 0;

    if (cooldown_timer > 0) {
        cooldown_timer--;
        return 0;
    }

    uint8_t current_state = (GPIOA->IDR & GPIO_IDR_ID3) ? 1 : 0;

    if (!last_state && current_state) {
        last_state = current_state;
        cooldown_timer = DEBOUNCE_DELAY;
        return 1;
    }

    last_state = current_state;
    return 0;
}

///////////////////////////////////////////////////////////////////////////////
// Helper: scale function
///////////////////////////////////////////////////////////////////////////////
uint8_t scale_1p5_and_clamp(uint8_t v) {
    int16_t scaled = (int16_t)(((v - 128) * 3 / 2) + 128);
    if (scaled > 255) scaled = 255;
    if (scaled < 0) scaled = 0;
    return (uint8_t)scaled;
}

///////////////////////////////////////////////////////////////////////////////
// System Clock
///////////////////////////////////////////////////////////////////////////////
void SystemClock_Config(void) {
    RCC->CR |= RCC_CR_HSION;
    while(!(RCC->CR & RCC_CR_HSIRDY));

    RCC->APB1ENR1 |= RCC_APB1ENR1_PWREN;
    PWR->CR1 |= PWR_CR1_VOS_0;
    PWR->CR1 &= ~PWR_CR1_VOS_1;
    while ((PWR->SR2 & PWR_SR2_VOSF));

    FLASH->ACR = FLASH_ACR_ICEN | FLASH_ACR_DCEN | FLASH_ACR_LATENCY_4WS;

    RCC->PLLCFGR = (RCC_PLLCFGR_PLLSRC_HSI | 
                    RCC_PLLCFGR_PLLM_0 |
                    (20 << RCC_PLLCFGR_PLLN_Pos) |
                    RCC_PLLCFGR_PLLREN);
    
    RCC->CR |= RCC_CR_PLLON;
    while(!(RCC->CR & RCC_CR_PLLRDY));

    RCC->CFGR |= RCC_CFGR_SW_PLL;
    while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL);

    SystemCoreClockUpdate();
}

///////////////////////////////////////////////////////////////////////////////
// MAIN
///////////////////////////////////////////////////////////////////////////////
int main(void) {

    SystemClock_Config();
    SystemCoreClockUpdate();

    initSPI3(0b010, 0, 0);
    initSPI1_FPGA();

    pinMode(SQUARE_WAVE_PIN, GPIO_OUTPUT);
    pinMode(FPGA_AUDIO_CS_PIN, GPIO_OUTPUT);
    digitalWrite(FPGA_AUDIO_CS_PIN, 1);

    pinMode(FPGA_ADC_CS_PIN, GPIO_OUTPUT);
    digitalWrite(FPGA_ADC_CS_PIN, 1);

    pinMode(PA8, GPIO_OUTPUT);
    digitalWrite(PA8, 0);

    ADC_Init();
    Button_Init();

    fres = f_mount(&FatFs, "", 1);
    if (fres != FR_OK) { blink_error(4); while(1); }

    scan_wav_files();
    if (wav_file_count == 0) { blink_error(8); while(1); }

    open_next_wav_file();
    TIM2_Init_Default();

    printf("Streaming Audio & ADC to FPGA...\n");

    while (1) {

        if (check_button()) {
            printf("Button pressed! Skipping track...\n");

            if (open_next_wav_file() == 0) {
                f_read_counter = 0;
            }
        }

        if (f_read_ready_flag) {
            f_read_ready_flag = 0;

            fres = f_read(&file, audio_buffer, 512, &bytesRead);

            if (fres != FR_OK || bytesRead == 0) {
                if (open_next_wav_file() < 0) {
                    blink_error(7);
                    while (1);
                }
                f_read(&file, audio_buffer, 512, &bytesRead);
            }

            // AUDIO TO FPGA
            send_spi_data(audio_buffer, bytesRead, GPIO_ODR_OD2);

            // SENSOR TO FPGA
            uint8_t sensor_val = Read_ADC_Channel(ADC_PIN_SEND);
            uint8_t sensor_scaled = scale_1p5_and_clamp(sensor_val);
            send_spi_data(&sensor_scaled, 1, GPIO_ODR_OD6);
        }
    }
}
