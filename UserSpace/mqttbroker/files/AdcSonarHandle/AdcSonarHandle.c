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

#include "AdcSonarHandle.h"
#include <stdlib.h>   // <-- add this for system()
#include <stdio.h>    // for snprintf
#include <fcntl.h>   // for open
#include <stdbool.h> // for bool
#include <stdint.h>  // for uint32_t, etc.
#include <unistd.h>  // for read, close


/* Static variables */
static char* AdcSonarKo = "adcsonar";
static char AdcSonarKo_String[128];
/* public variables */

/* global functions */
uint8_t AdcSonarHandle_Init(void)
{
    // Build the command string
    snprintf(AdcSonarKo_String, sizeof(AdcSonarKo_String), "modprobe %s", AdcSonarKo);
    // Load module
    if (system(AdcSonarKo_String) != 0)
    {
        perror("modprobe");
        return 1;
    }

    printf("Module started successfully\n");
    return 0;
}

uint8_t AdcSonarHandle_DeInit(void)
{
    // Build the command string
    snprintf(AdcSonarKo_String, sizeof(AdcSonarKo_String), "modprobe -r %s", AdcSonarKo);
    // Unload module
    if (system(AdcSonarKo_String) != 0)
    {
        perror("modprobe");
        return 1;
    }

    printf("Module ended successfully\n");
    return 0;
}

bool AdcSonarHandle_ReadData(ADCSONARHANDLE_DATA* data)
{
    uint32_t version_prev = data->version;
    int fd = open("/dev/adcsonar", O_RDONLY);
    if (read(fd, data, sizeof(ADCSONARHANDLE_DATA)) != sizeof(ADCSONARHANDLE_DATA))
    {
        close(fd);
        return false;
    }
    /* Close nevertheless */
    close(fd);
    return (version_prev != data->version);
}
