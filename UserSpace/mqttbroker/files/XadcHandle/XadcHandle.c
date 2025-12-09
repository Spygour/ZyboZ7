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
#include <fcntl.h>
#include <unistd.h>
#include "XadcHandle.h"
#include <string.h>

/* Static variables */
static char *XadcDev = "f8007100.adc";
static char *XadcPath = "/sys/bus/platform/drivers/xadc/f8007100.adc";
/* public variables */

/* global functions */
uint8_t XadcUnbindDriver(void)
{
    uint8_t status = 0;
    if ((access(XadcPath, F_OK) == 0))
    {
        /* Xadc is bind lets unbind*/
        printf("Module is active, unbind... \n");
        int fd = open("/sys/bus/platform/drivers/xadc/unbind", O_WRONLY);
        if(fd < 0) { perror("open"); return 1; }

        if(write(fd, XadcDev, strlen(XadcDev)) < 0) {
            close(fd);
            perror("write");
            return 1;
        }
        close(fd);
        printf("Unbound xadc\n");
        status = 0;
    }
    else {
        printf("Module is already unbind \n");
        status = 0;
    }
    return status;
}

uint8_t XadcBindDriver(void)
{
    int fd = open("/sys/bus/platform/drivers/xadc/bind", O_WRONLY);
    if(fd < 0) { perror("open"); return 1; }

    if(write(fd, XadcDev, strlen(XadcDev)) < 0) {
        perror("write");
        return 1;
    }

    close(fd);
    printf("Unbound xadc\n");
    return 0;
}
