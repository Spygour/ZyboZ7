#include "I2s.h"
#include "xparameters.h"
#include <stdio.h>
#include "xil_types.h"
#include "xil_io.h"
#include "sleep.h"
//#include "xi2stx.h"
//#include "xi2srx.h"
#include "xil_exception.h"
#include "stdbool.h"


#define PEDALBOAD_CFG1_REG 0x0
#define PEDALBOAD_CFG2_REG 0x4
#define PEDALBOAD_CFG3_REG 0x8
//XI2s_Tx I2s_TxDrv;
//XI2s_Rx I2s_RxDrv;

typedef struct
{
	uint32_t EN0:1;
	uint32_t mode:2;
	uint32_t normalizer:5;
	uint32_t threshold_high:24;
}Pedalboard_cfg_Bits;

typedef struct 
{
	uint32_t threshold_low:24;
	uint32_t gain:8;
}Pedalboard_cfg2_Bits;

typedef struct 
{
	uint32_t qubic:7;
	uint32_t compressor:24;
	uint32_t none:1;
}Pedalboard_cfg3_Bits;

typedef union
{
	unsigned int U;
	Pedalboard_cfg_Bits B;
}PedalBoard_CFG1;

typedef union
{
	unsigned int U;
	Pedalboard_cfg2_Bits B;
}PedalBoard_CFG2;

typedef union
{
	unsigned int U;
	Pedalboard_cfg3_Bits B;
}PedalBoard_CFG3;

static PedalBoard_CFG1 PedalBoard_Cfg1Reg;
static PedalBoard_CFG2 PedalBoard_Cfg2Reg;
static PedalBoard_CFG3 PedalBoard_Cfg3Reg;

PedalBoard_Cfg_t PedalBoard_Cfg = {
	8,
	RAW_OUTPUT,
	0x7FFFFF,
	-0x800000,
	2,
	50,
	0x400000
};

static void PedalBoard_SetNormalization(uint32_t normalization)
{
	if (normalization > 15)
	{
		normalization = 15;
	}
	PedalBoard_Cfg1Reg.B.normalizer = (uint32_t)(normalization & 0x1F);
}

static void PedalBoard_SetHighThreshold(int32_t threshold)
{
	if (threshold > 0x7FFFFF)
	{
		threshold = 0x7FFFFF;
	}
	else if (threshold < -0x800000)
	{
		threshold = -0x800000;
	}
	PedalBoard_Cfg1Reg.B.threshold_high = (uint32_t)(threshold & 0xFFFFFF);
}

static void PedalBoard_SetLowThreshold(int32_t threshold)
{
	if (threshold > 0x7FFFFF)
	{
		threshold = 0x7FFFFF;
	}
	else if (threshold < -0x800000)
	{
		threshold = -0x800000;
	}
	PedalBoard_Cfg2Reg.B.threshold_low = (uint32_t)(threshold & 0xFFFFFF);
}

static void PedalBoard_SetGain(int8_t gain)
{
	if (gain > 127)
	{
		gain = 127;
	}
	else if (gain < -128)
	{
		gain = -128;
	}
	PedalBoard_Cfg2Reg.B.gain = (uint32_t)(gain & 0xFF);
}

static void PedalBoard_SetMode(PedalBoard_DistMode_t mode)
{
	PedalBoard_Cfg1Reg.B.mode = (uint32_t)mode;
}

static void PedalBoard_SetDistortionShift(uint8_t qubic)
{
	PedalBoard_Cfg3Reg.B.qubic = (qubic & 0x7F);
}

static void PedalBoard_SetCompressor(uint32_t compressor)
{
	PedalBoard_Cfg3Reg.B.compressor = (compressor & 0x7FFFFF); /* 23 BITS cause its signed in the hardware */
}

int PedalBoard_Init(void)
{

	Xil_Out32(XPAR_GUITARPRESETS_0_BASEADDR + PEDALBOAD_CFG1_REG, 0x0);
	Xil_Out32(XPAR_GUITARPRESETS_0_BASEADDR + PEDALBOAD_CFG2_REG, 0x0);
	msleep(100);
	PedalBoard_SetMode(PedalBoard_Cfg.mode);
	PedalBoard_SetNormalization(PedalBoard_Cfg.normalizer);
	PedalBoard_SetHighThreshold(PedalBoard_Cfg.threshold_high);
	PedalBoard_SetLowThreshold(PedalBoard_Cfg.threshold_low);
	PedalBoard_SetGain(PedalBoard_Cfg.gain);
	PedalBoard_SetDistortionShift(PedalBoard_Cfg.shift_qubic);
	PedalBoard_SetCompressor(PedalBoard_Cfg.compressor);
	PedalBoard_Cfg1Reg.B.EN0 = 1U;
	Xil_Out32(XPAR_GUITARPRESETS_0_BASEADDR + PEDALBOAD_CFG1_REG, PedalBoard_Cfg1Reg.U);
	Xil_Out32(XPAR_GUITARPRESETS_0_BASEADDR + PEDALBOAD_CFG2_REG, PedalBoard_Cfg2Reg.U);
	Xil_Out32(XPAR_GUITARPRESETS_0_BASEADDR + PEDALBOAD_CFG3_REG, PedalBoard_Cfg3Reg.U);
    /* Then enable the transmiter */
    //XI2s_Tx_Enable(&I2s_TxDrv, true);

    return XST_SUCCESS;
}

void PedalBoard_100ms(void)
{
	PedalBoard_SetMode(PedalBoard_Cfg.mode);
	PedalBoard_SetNormalization(PedalBoard_Cfg.normalizer);
	PedalBoard_SetHighThreshold(PedalBoard_Cfg.threshold_high);
	PedalBoard_SetLowThreshold(PedalBoard_Cfg.threshold_low);
	PedalBoard_SetGain(PedalBoard_Cfg.gain);
	PedalBoard_SetCompressor(PedalBoard_Cfg.compressor);
	Xil_Out32(XPAR_GUITARPRESETS_0_BASEADDR + PEDALBOAD_CFG1_REG, PedalBoard_Cfg1Reg.U);
	Xil_Out32(XPAR_GUITARPRESETS_0_BASEADDR + PEDALBOAD_CFG2_REG, PedalBoard_Cfg2Reg.U);
	Xil_Out32(XPAR_GUITARPRESETS_0_BASEADDR + PEDALBOAD_CFG3_REG, PedalBoard_Cfg3Reg.U);
}