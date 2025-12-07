/* Includes */
#include "xadc.h"
#include <linux/delay.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/irq.h>
#include <linux/of.h>
#include <linux/of_irq.h>

/* Definitions */

/* Types */

/* local variables */
static int Xadc_InterruptId;
static void (*Xadc_Cb)(void);

/* public variables */
void __iomem* Xadc_Base;

/* static functions */
static inline int Xadc_InterruptCheck(const char* compat)
{
    struct device_node* np;
    np = of_find_compatible_node(NULL, NULL, compat); /* Please modify this */
    if (!np)
    {
        pr_err("Adc node was not find in device tree\n");
        return -ENODEV;
    }

    Xadc_InterruptId = irq_of_parse_and_map(np, 0);
    if (Xadc_InterruptId <= 0)
    {
        pr_err("Adc interrupt not mapped\n");
        of_node_put(np);
        return -EINVAL;
    }

    pr_info("Mapped Adc IRQ = %d\n", Xadc_InterruptId);
    of_node_put(np);

    return 0;
}

static irqreturn_t Xadc_Irq(int irq, void* lp)
{
    /* Read status register in order to clear it */
    uint32_t intrflag = ioread32(Xadc_Base + XADC_STATUS_OFFSET);
    /* Clear the SEQUENCE interrupt */
    // iowrite32(XADC_EOS_CLEAR_BIT, Xadc_Base + XADC_INTR_STATUS_OFFSET);

    /* Go to the callback */
    if (Xadc_Cb)
    {
        Xadc_Cb();
    }
    return IRQ_HANDLED;
}

/* global functions */
void Xadc_Init(XADC_CONFIG_T* config)
{
    /* First get the xadc address */
    Xadc_Base = ioremap(config->xadc_base_address, config->axi_size);
    if (!Xadc_Base)
    {
        pr_err("Failed to map AXI1\n");
        return;
    }
    /* Reset the xadc */
    iowrite32(XADC_RESET, Xadc_Base + XADC_RESET_OFFSET);
    /* Add a small delay */
    usleep_range(100, 200);

    /* Check if interrupt is needed */
    if (config->intr_en)
    {
        /* Asign the irq handler */
        Xadc_Cb = config->irq_handler;

        /* Get first the interrupt mapped on yocto */
        if (Xadc_InterruptCheck(config->device_string) < 0)
        {
            pr_err("Change the string is wrong \n");
            return;
        }
        int ret = request_irq(Xadc_InterruptId, Xadc_Irq, 0, "adc_isr", NULL);
        if (ret)
        {
            pr_err("Request of interrupt failed \n");
            return;
        }
        /* First read to clear the status */
        uint32_t intrflag = ioread32(Xadc_Base + XADC_STATUS_OFFSET);
        /* Clear interrupt flags */
        intrflag = ioread32(Xadc_Base + XADC_INTR_STATUS_OFFSET);
        iowrite32(intrflag | (XADC_EOS_CLEAR_BIT | XADC_EOC_CLEAR_BIT), Xadc_Base + XADC_INTR_STATUS_OFFSET);
        /* Configure xadc interrupts, SEQUENCE INTERRUPT */
        iowrite32(XAD_EOS_INT_ENABLE, Xadc_Base + XADC_INTR_ENABLE_OFFSET);
        iowrite32(XADC_GLOBAL_INTR_ENABLE, Xadc_Base + XADC_GLOBAL_INTR_ENABLE_OFFSET);
    }

    if (config->seq_mode_en)
    {
        if (config->seq_channel_mask >= 0x10000)
        {
            pr_err("Please change channel mask\n");
            return;
        }
        /* Enable channel on sequence */
        iowrite32(config->seq_channel_mask, Xadc_Base + XADC_SEQ_AUX_CH_SEL_OFFSET);
        if (config->config1.B.bibolar_en == 1u)
        {
            /* Same input mode as channel mask */
            iowrite32(config->seq_channel_mask, Xadc_Base + XADC_SEQ_CH_INPUT_MODE_OFFSET);
        }
    }
    /* Configure the adc by writing to configuration registers*/
    iowrite32(config->config1.U, Xadc_Base + XADC_CONFIG1_OFFSET);
    iowrite32(config->config2.U, Xadc_Base + XADC_CONFIG2_OFFSET);
    iowrite32(config->config3.U, Xadc_Base + XADC_CONFIG3_OFFSET);
}

void Xadc_DeInit(void)
{
    /* Disable interrupts */
    iowrite32(0x0, Xadc_Base + XADC_INTR_ENABLE_OFFSET);
    iowrite32(0x0, Xadc_Base + XADC_GLOBAL_INTR_ENABLE_OFFSET);
    /* Clear config registers */
    iowrite32(0x0, Xadc_Base + XADC_CONFIG1_OFFSET);
    iowrite32(0x0, Xadc_Base + XADC_CONFIG2_OFFSET);
    iowrite32(0x0, Xadc_Base + XADC_CONFIG3_OFFSET);
    /* Clear sequence registers */
    iowrite32(0x0, Xadc_Base + XADC_SEQ_AUX_CH_SEL_OFFSET);
    iowrite32(0x0, Xadc_Base + XADC_SEQ_CH_INPUT_MODE_OFFSET);
    /* Clear interrupts */
    (void)ioread32(Xadc_Base + XADC_STATUS_OFFSET);
    iowrite32(XADC_EOS_CLEAR_BIT | XADC_EOC_CLEAR_BIT, Xadc_Base + XADC_INTR_STATUS_OFFSET);
    if (Xadc_Base)
    {
        iounmap(Xadc_Base);
        Xadc_Base = NULL;
    }
    if (Xadc_InterruptId > 0)
    {
        free_irq(Xadc_InterruptId, NULL);
        Xadc_InterruptId = 0;
    }
    printk(KERN_ALERT "Xadc has been deinitialized\n");
}

void Xadc_ReadChannel(uint16_t num, uint16_t* value)
{
    if (num > 15)
    {
        pr_err("Wrong Channel bro \n");
        return;
    }
    else
    {
        uint32_t channel_offset = (num << 2) + XADC_VAUX0_RES;

        *value = ioread32(Xadc_Base + channel_offset);
    }
}

bool Xadc_GetSeqFlagAndClear(void)
{
    uint32_t intrflag = ioread32(Xadc_Base + XADC_INTR_STATUS_OFFSET);
    uint32_t intrmask = XADC_EOS_CLEAR_BIT | XADC_EOC_CLEAR_BIT;
    if ((intrflag & intrmask) == intrmask)
    {
        iowrite32(intrflag | intrmask, Xadc_Base + XADC_INTR_STATUS_OFFSET);
        return true;
    }
    else
    {
        return false;
    }
}

bool Xadc_GetSeqStatusAndClear(void)
{
    uint32_t intrflag = ioread32(Xadc_Base + XADC_STATUS_OFFSET);
    uint32_t intrmask = XADC_EOC_STATUS | XADC_EOS_STATUS;
    if ((intrflag & intrmask) == intrmask)
    {
        iowrite32(intrflag | (XADC_EOS_CLEAR_BIT | XADC_EOC_CLEAR_BIT), Xadc_Base + XADC_INTR_STATUS_OFFSET);
        return true;
    }
    else
    {
        return false;
    }
}

void Xadc_RestartSequence(void)
{
    XADC_CONFIG2_T config2;
    config2.U = ioread32(Xadc_Base + XADC_CONFIG2_OFFSET);
    /* Set mode to default */
    config2.B.channel_seq_mode = 0x0;
    iowrite32(config2.U, Xadc_Base + XADC_CONFIG2_OFFSET);
    /* Restart the fucking sequence */
    config2.B.channel_seq_mode = XADC_SINGLE_PASS_SEQ_MODE;
    iowrite32(config2.U, Xadc_Base + XADC_CONFIG2_OFFSET);
}
