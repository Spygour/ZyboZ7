#include "I2c.h"
#include "xparameters.h"
#include <stdio.h>
#include <xstatus.h>
#include "xiic.h"
#include "xil_exception.h"
#include "stdbool.h"
#include "sleep.h"

#define I2C_IRQ_ID 61U

#define LEFT_ADC_VOL_REG 0x0
#define RIGHT_ADC_VOL_REG 0x1
#define LEFT_DAC_VOL_REG 0x2
#define RIGHT_DAC_VOL_REG 0x3
#define ANALOG_AUDIO_CTRL_REG 0x4
#define DIGITAL_AUDIO_CTRL_REG 0x5
#define POW_MNG_REG 0x6
#define DIGITAL_AUDIO_RATE 0x7
#define SAMPLING_RATE_REG 0x8
#define ACTIVE_REG 0x9
#define RESET_REG 0x0F

static XIic I2cInstance;
static volatile bool I2c_TxComplete = false;
static volatile bool I2c_RxComplete = false;
uint16_t I2c_TxBuffer[20];
uint16_t I2c_RxBuffer[20];

void I2cIsrHandler(void *CallbackRef) {

}

void I2cTxHandler(XIic *InstancePtr, int ByteCount)
{
    I2c_TxComplete = true;
}

void I2cRxHandler(XIic *InstancePtr, int ByteCount)
{
    I2c_RxComplete = true;
}

void I2cStatusHandler(XIic *InstancePtr, int Event)
{

}

int I2c_CodecWrite(uint8_t reg, uint16_t value)
{
	u8 u8TxData[2];
	u8 u8BytesSent;

	u8TxData[0] = reg << 1;
	u8TxData[0] = u8TxData[0] | ((uint8_t)((value>>8) & 0b1));

	u8TxData[1] = value & 0xFF; /* Bit 8 should be moved*/

	u8BytesSent = XIic_Send(XPAR_AXI_IIC_0_BASEADDR, 0x1A, u8TxData, 2, XIIC_STOP);

	//check if all the bytes where sent
	if (u8BytesSent != 2)
	{
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}

int I2c_CodecRead(uint8_t reg, uint16_t *recvPtr)
{
	u8 u8TxData[2];
	u8 u8RxData[2];
	u8 u8BytesSent, u8BytesReceived;

	u8TxData[0] = reg;
	u8TxData[1] = 0x1A;



	u8BytesSent = XIic_Send(XPAR_AXI_IIC_0_BASEADDR, 0x1A, u8TxData, 1, XIIC_REPEATED_START);
	//check if all the bytes where sent
	if (u8BytesSent != 1)
	{
		return XST_FAILURE;
	}

	u8BytesReceived = XIic_Recv(XPAR_AXI_IIC_0_BASEADDR, 0x1A, u8RxData, 2, XIIC_REPEATED_START);
	//check if there are missing bytes
	if (u8BytesReceived != 2)
	{
		return XST_FAILURE;
	}
	/* Store the data on the recvPtr */
	*recvPtr = (uint16_t)u8RxData[0];
	/* Here we store nevertheless the data on other bytes */
	*recvPtr |= ( (uint16_t)u8RxData[1] << 8);

	return XST_SUCCESS;
}


int I2c_Init(XScuGic *InstancePtr)
{
    int Status;
    I2c_TxComplete = true;
    I2c_RxComplete = true;

    
	Status = XIic_Initialize(&I2cInstance, XPAR_AXI_IIC_0_BASEADDR); 
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    Status = XIic_DynamicInitialize(&I2cInstance);
    	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    /*
	 * Set the Slave address.
	 */
    int CodecAddr = 0x1A;
	Status = XIic_SetAddress(&I2cInstance, XII_ADDR_TO_SEND_TYPE,
				 CodecAddr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

    XIic_SetOptions(&I2cInstance, I2cInstance.Options | XII_REPEATED_START_OPTION);
    /*
	 * Set the Handlers for transmit and reception.
	 */
	XIic_SetSendHandler(&I2cInstance, &I2cInstance,
			    (XIic_Handler) I2cTxHandler);
	XIic_SetRecvHandler(&I2cInstance, &I2cInstance,
			    (XIic_Handler) I2cRxHandler);
	XIic_SetStatusHandler(&I2cInstance, &I2cInstance,
			      (XIic_StatusHandler) I2cStatusHandler);

    //XScuGic_SetPriorityTriggerType(InstancePtr, XPAR_FABRIC_AXI_IIC_0_INTR, 0xA0, 0x3);
    XScuGic_SetPriorityTriggerType(InstancePtr, I2C_IRQ_ID, 0xA0, 0x3);
    XScuGic_Connect(InstancePtr, I2C_IRQ_ID, (Xil_InterruptHandler)XIic_InterruptHandler, &I2cInstance);
    XScuGic_Enable(InstancePtr, I2C_IRQ_ID);

    return XST_SUCCESS;
}

int I2c_CodecConfig(void)
{
	int Status;
	/* Reset */
	Status = I2c_CodecWrite(RESET_REG, 0x0);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	/* Delay for 500 ms */
	msleep(500);
	/* Enable power with mic disabled */
	Status = I2c_CodecWrite(POW_MNG_REG, 0x30);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	/* Configure left adc channel */
	Status = I2c_CodecWrite(LEFT_ADC_VOL_REG, 0x21);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	/* Configure right adc channel */
	Status = I2c_CodecWrite(RIGHT_ADC_VOL_REG, 0x21);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	/* Configure left dac channel */
	Status = I2c_CodecWrite(LEFT_DAC_VOL_REG, 0x79);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	/* Configure right dac channel */
	Status = I2c_CodecWrite(RIGHT_DAC_VOL_REG, 0x79);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	/* Configure the analog audio path to be line */
	Status = I2c_CodecWrite(ANALOG_AUDIO_CTRL_REG, 0x10);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	/* Configure the digital audio path */
	Status = I2c_CodecWrite(DIGITAL_AUDIO_CTRL_REG, 0x1);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	/* Digital audio filter config */
	Status = I2c_CodecWrite(DIGITAL_AUDIO_RATE, 0xA);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	/* Sampling rate */
	Status = I2c_CodecWrite(SAMPLING_RATE_REG, 0x0);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	/* Delay for 500 ms */
	msleep(500);

	/* Enable digital core */
	Status = I2c_CodecWrite(ACTIVE_REG, 0x1);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	Status = I2c_CodecWrite(POW_MNG_REG, 0x20);
	if (Status != XST_SUCCESS)
	{
		return XST_FAILURE;
	}

	return XST_SUCCESS;
}


void I2c_ChangeMute(bool val)
{
	(void)XIic_SetGpOutput(&I2cInstance, val);
}
