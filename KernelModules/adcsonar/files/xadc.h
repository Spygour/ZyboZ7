#ifndef __XADC_H
#define __XADC_H

/* Kernel includes */
#include <linux/types.h>   /* u32, u16, bool */
#include "stdint.h"
#include "stdbool.h"
#include <linux/io.h>      /* __iomem */
/* Includes */


/* Definitions */
#define XADC_RESET_OFFSET 0x00U
#define XADC_STATUS_OFFSET 0x04U
#define XADC_ALARM_OFFSET 0x08U
#define XADC_CONV_CONTROL_OFFSET 0x0CU
#define XADC_GLOBAL_INTR_ENABLE_OFFSET 0x5CU
#define XADC_INTR_STATUS_OFFSET 0x60U
#define XADC_INTR_ENABLE_OFFSET 0x68U
#define XADC_ERROR_FLAG_OFFSET 0x2FCU
#define XADC_VAUX0_RES 0x240U
#define XADC_VAUX6_RES 0x258U
#define XADC_VAUX7_RES 0x25CU
#define XADC_VAUX14_RES 0x278U
#define XADC_VAUX15_RES 0x27CU
#define XADC_CONFIG1_OFFSET 0x300U
#define XADC_CONFIG2_OFFSET 0x304U
#define XADC_CONFIG3_OFFSET 0x308U
#define XADC_SEQ_AUX_CH_SEL_OFFSET 0x324U
#define XADC_SEQ_CH_AVG_EN_OFFSET 0x32CU
#define XADC_SEQ_CH_INPUT_MODE_OFFSET 0x334U
#define XADC_SEQ_CH_ACQ_TIME_OFFSET 0x33C


#define XADC_RESET 0x01U
#define XADC_GLOBAL_INTR_ENABLE (0x1U << 31)
#define XADC_EOC_INT_ENABLE (0x01U << 5)
#define XAD_EOS_INT_ENABLE (0x01 << 4)
#define XADC_CONV_START 0x01U
#define XADC_ALARM_OVERTEMP_VCCUAX (0x1U << 5)

#define XADC_CHANNEL_VAUX6 0x10u
#define XADC_CHANNEL_VAUX7 0x11u
#define XADC_CHANNEL_VAUX14 0x18U
#define XADC_CHANNEL_VAUX15 0x19U

#define XADC_AVERAGING_16_SAMPLES 0x1U
#define XADC_DCLCK_DIV_4 0x4U

#define XADC_SINGLE_PASS_SEQ_MODE 0x1U

#define XADC_OFFSET_CORR_EN 0x01U
#define XADC_OFFSET_GAIN_CORR_EN 0x02U
#define XADC_SENSOR_OFFSET_CORR_EN 0x04U
#define XADC_SENSOR_OFFSET_GAIN_CORR_EN 0x08U

#define XADC_POWER_UP 0x00U
#define XADC_ADCB_POWER_DOWN 0x02U
#define XADC_POWER_DOWN 0x03U

/* End of sequence clear */
#define XADC_EOS_CLEAR_BIT (0x1 << 4)
/* End of conversion clear*/
#define XADC_EOC_CLEAR_BIT (0x1 << 5)
/* Types */
typedef union
{
  struct
  {
    uint32_t channel:5;
    uint32_t reserved1:3;
    uint32_t settling_time_increase:1;
    uint32_t event_mode_en:1;
    uint32_t bibolar_en:1;
    uint32_t external_mux_en:1;
    uint32_t averaging_sample:2;
    uint32_t reserved2:1;
    uint32_t disable_average:1;
    uint32_t reserved3:16;
  }B;
  uint32_t U;

}XADC_CONFIG1_T;

typedef union
{
  struct
  {
    uint32_t overtemp_alm_dis:1;
    uint32_t alarms_int_dis:3;
    uint32_t calib_en:4;
    uint32_t alarm_int_dis:1;
    uint32_t alarm_ext_dis:3;
    uint32_t channel_seq_mode:4;
    uint32_t reserved:16;
  }B;
  uint32_t U;
}XADC_CONFIG2_T;

typedef union
{
  struct
  {
    uint32_t reserved1:4;
    uint32_t power_down_en:2;
    uint32_t reserved2:2;
    uint32_t drp_clk_pre:8;
    uint32_t reserved3:16;
  }B;
  uint32_t U;
}XADC_CONFIG3_T;


typedef struct 
{
  XADC_CONFIG1_T config1;
  XADC_CONFIG2_T config2;
  XADC_CONFIG3_T config3;
  uint32_t seq_channel_mask;
  bool  interrupt_enable;
  bool  sequence_mode_en;
  void (*irq_handler)(void);
  uint32_t xadc_base_address; /* Warning this is the base address that you see from vivado side */
  uint32_t axi_size;
  const char* device_string;
}XADC_CONFIG_T;

typedef union
{
  struct
  {
    uint32_t channel_id:5;
    uint32_t conv_end:1;
    uint32_t end_of_sequence:1;
    uint32_t adc_busy:1;
    uint32_t jtag_locked:1;
    uint32_t jtag_modified:1;
    uint32_t jtag_busy:1;
    uint32_t reserved:21;
  }B;
  uint32_t U;
}XADC_STATUS_T;

/* public variables */
extern void __iomem *Xadc_Base;

/* static functions */


/* global functions */
void Xadc_Init(XADC_CONFIG_T* config);
void Xadc_DeInit(void);
bool Xadc_StartConvertion(void);
void Xadc_ReadChannel(uint16_t num, uint16_t* value);

#endif /*__xadc_H */