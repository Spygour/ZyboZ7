/*
* Copyright (C) 2013-2022  Xilinx, Inc.  All rights reserved.
* Copyright (c) 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
*
* Permission is hereby granted, free of charge, to any person
* obtaining a copy of this software and associated documentation
* files (the "Software"), to deal in the Software without restriction,
* including without limitation the rights to use, copy, modify, merge,
* publish, distribute, sublicense, and/or sell copies of the Software,
* and to permit persons to whom the Software is furnished to do so,
* subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included
* in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
* CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in this
* Software without prior written authorization from Xilinx.
*
*/

#include <stdio.h>
#include <unistd.h>
#include "XadcHandle.h"
#include "AdcSonarHandle.h"

typedef enum 
{
    UNBIND_XADC,
    START_XADC_KERNEL,
    READ_DATA,
    SEND_TO_SERVER,
    BIND_XADC
} MQTT_BROKER_STATE;

static MQTT_BROKER_STATE mqttbroker_state = UNBIND_XADC;
static uint8_t endFlag = 0;

static void MqttMainRunnable(void)
{
    switch(mqttbroker_state)
    {
        case UNBIND_XADC:
            endFlag = XadcUnbindDriver();
            mqttbroker_state = START_XADC_KERNEL;
            break;

        case START_XADC_KERNEL:
            endFlag = AdcSonarHandle_Init();
            mqttbroker_state = READ_DATA;
            break;

        case READ_DATA:

            break;

        case SEND_TO_SERVER:

            break;

        case BIND_XADC:
            (void)AdcSonarHandle_DeInit();
            (void)XadcBindDriver();
            endFlag = 1; // End the program here please
            break;

        default:
            break;
    }
}
 
int main(int argc, char **argv)
{
    printf("Hello World!, first unbind the Xadc\n");

    mqttbroker_state = UNBIND_XADC;
    endFlag = 0;

    while (!endFlag)
    {
        MqttMainRunnable(); // Update the flag for now the error handler is afterwards
        usleep(100000);  // 100 ms delay
    }

    return 0;
}
