#ifndef I2S_H_
#define I2S_H_
#include <stdint.h>
#include <stdbool.h>
typedef enum
{
    RAW_OUTPUT,
    DISTORTION,
    FUZZY,
    FUZZY_COPY,
}PedalBoard_DistMode_t;

typedef struct
{
    bool enable;
    uint8_t inc;
    uint8_t max_value;
    uint8_t max_time;
}phase_cfg_t;

typedef struct
{
    bool isStart;
    uint32_t normalizer;
    PedalBoard_DistMode_t mode;
    int32_t threshold_high;
    int32_t threshold_low;
    uint8_t shift_qubic;
    int8_t gain;
    uint32_t compressor;
    int8_t highpass;
    int8_t lowpass;
    phase_cfg_t phaseCfg;
}PedalBoard_Cfg_t;

extern int PedalBoard_Init(void);
extern void PedalBoard_100ms(void);
#endif