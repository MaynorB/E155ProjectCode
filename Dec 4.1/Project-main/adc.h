#ifndef ADC_H
#define ADC_H

#include <stdint.h>

// Public API
void ADC_Init(void);
uint8_t Read_ADC_Channel(uint8_t channel);

#endif
