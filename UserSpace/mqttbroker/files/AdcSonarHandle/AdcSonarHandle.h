#ifndef __ADCSONARHANDLE_H
#define __ADCSONARHANDLE_H

#include <stdbool.h>
#include <stdint.h>


/* TYPES */
typedef struct
{
    uint32_t distance;
    uint32_t version;
} ADCSONARHANDLE_DATA;

/* global functions */
uint8_t AdcSonarHandle_Init(void);
uint8_t AdcSonarHandle_DeInit(void);
bool AdcSonarHandle_ReadData(ADCSONARHANDLE_DATA* data);
#endif /*__AdcSonarHandle_H */