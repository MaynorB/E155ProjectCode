#ifndef SPI_FPGA_H
#define SPI_FPGA_H

#include <stdint.h>

void initSPI1_FPGA(void);
void send_spi_data(uint8_t *buf, uint16_t len, uint32_t cs_pin_mask);

#endif
