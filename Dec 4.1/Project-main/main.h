#ifndef MAIN_H
#define MAIN_H

#include "stm32l432xx.h"
#include "STM32L432KC_SPI.h"
#include "SD_lowlevel.h"
#include "STM32L432KC_GPIO.h"
#include "ff.h"
#include "diskio.h"
#include <string.h>
#include <stdio.h>
#include <ctype.h>

///////////////////////////////////////////////////////////////////////////////
// Pin Definitions
///////////////////////////////////////////////////////////////////////////////
#define SQUARE_WAVE_PIN     PB0

// SPI1 → FPGA Chip Select Pins
#define FPGA_AUDIO_CS_PIN   PA2
#define FPGA_ADC_CS_PIN     PA6

// ADC channels
#define ADC_PIN_SPEED       5   // PA0
#define ADC_PIN_SEND        6   // PA1

// Button on PA3
#define BUTTON_PIN_PA3      3
#define DEBOUNCE_DELAY      5000

// WAV file limit
#define MAX_WAV_FILES 16

///////////////////////////////////////////////////////////////////////////////
// Global Variables (extern; defined in main.c)
///////////////////////////////////////////////////////////////////////////////
extern FATFS FatFs;
extern FIL file;
extern FRESULT fres;

extern BYTE audio_buffer[512];
extern UINT bytesRead;

extern volatile uint16_t f_read_counter;
extern volatile int f_read_ready_flag;
extern volatile uint16_t adc_counter;

extern char wav_files[MAX_WAV_FILES][32];
extern uint8_t wav_file_count;
extern int8_t current_file_index;

///////////////////////////////////////////////////////////////////////////////
// Function Prototypes (local only)
///////////////////////////////////////////////////////////////////////////////

// Clock / Timer Initialization
void SystemClock_Config(void);

// Delay / Error
void delay_ms(uint32_t ms);
void blink_error(uint8_t times);

// Button
void Button_Init(void);
int check_button(void);

// Helpers
uint8_t scale_1p5_and_clamp(uint8_t v);

#endif // MAIN_H
