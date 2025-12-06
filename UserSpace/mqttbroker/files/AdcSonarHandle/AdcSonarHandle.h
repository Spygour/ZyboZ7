#ifndef __ADCSONARHANDLE_H
#define __ADCSONARHANDLE_H

#include <stdint.h>
#include <stdbool.h>

/* TYPES */
typedef struct
{
  float distance;
  uint32_t version;
}ADCSONARHANDLE_DATA;

/* global functions */
uint8_t AdcSonarHandle_Init(void);
uint8_t AdcSonarHandle_DeInit(void);
bool AdcSonarHandle_ReadData(ADCSONARHANDLE_DATA* data);
#endif /*__AdcSonarHandle_H */