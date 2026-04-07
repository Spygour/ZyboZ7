#ifndef I2C_H_
#define I2C_H_

#include "xscugic.h"   // For Zynq GIC (PS interrupt controller)
#include <stdint.h>
#include <stdbool.h>

extern uint16_t I2c_TxBuffer[20];
extern uint16_t I2c_RxBuffer[20]; 

extern int I2c_Init(XScuGic *InstancePtr);
extern int I2c_CodecConfig(void);
extern int I2c_CodecWrite(uint8_t reg, uint16_t value);
extern int I2c_CodecRead(uint8_t reg, uint16_t *recvPtr);
extern void I2c_ChangeMute(bool val);
#endif