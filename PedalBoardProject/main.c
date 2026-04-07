#include "xil_types.h"
#include "xil_io.h"
#include "sleep.h"
#include "xparameters.h"
#include <stdint.h>
#include <stdio.h>
#include <xstatus.h>
#include "xscugic.h"   // For Zynq GIC (PS interrupt controller)
#include "xil_exception.h"
#include "stdbool.h"
#include "I2c/I2c.h"
#include "I2s/I2s.h"



#define XPAR_XSCUGIC_0_DEVICE_ID 0

XScuGic IntcInstance;


int main(void)
{
    int status;
    XScuGic_Config *IntcConfig;
    IntcConfig = XScuGic_LookupConfig(XPAR_XSCUGIC_0_DEVICE_ID);  // define it as 0 if needed
    XScuGic_CfgInitialize(&IntcInstance, IntcConfig, XPAR_XSCUGIC_0_BASEADDR);

    status = I2c_Init(&IntcInstance);
    if (status !=XST_SUCCESS)
    {
        return XST_DEVICE_IS_STOPPED;
    }
    
    status = I2c_CodecConfig();
    if (status !=XST_SUCCESS)
    {
        return XST_DEVICE_IS_STOPPED;
    }
    
    status = PedalBoard_Init();
    if (status !=XST_SUCCESS)
    {
        return XST_DEVICE_IS_STOPPED;
    }

    /* Enable the global interrupts */
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                             (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                             &IntcInstance);
    Xil_ExceptionEnable();
    while(1)
    {
        PedalBoard_100ms();
        /* Delay for 500 ms */
	    msleep(100);
    }
}
