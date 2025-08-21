#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/gpio.h>
#include <linux/kthread.h>
#include <linux/delay.h>

static struct task_struct *thread;
static int led_gpio0 = 512;  // your GPIO number
static int led_gpio1 = 513;  // your GPIO number

static int led_thread(void *data) {
    while (!kthread_should_stop()) {
        gpio_set_value(led_gpio0, 1);
        gpio_set_value(led_gpio1, 0);
        msleep(1000);
        gpio_set_value(led_gpio0, 0);
        gpio_set_value(led_gpio1, 1);
        msleep(1000);
    }
    return 0;
}

static int __init led_init(void) {
    gpio_request(led_gpio0, "first_led");
    gpio_request(led_gpio1, "second_led");
    gpio_direction_output(led_gpio0, 0);
    gpio_direction_output(led_gpio1, 0);
    thread = kthread_run(led_thread, NULL, "led_thread");
    return 0;
}

static void __exit led_exit(void) {
    kthread_stop(thread);
    gpio_set_value(led_gpio0, 0);
    gpio_set_value(led_gpio1, 0);
    gpio_free(led_gpio0);
    gpio_free(led_gpio1);
}

module_init(led_init);
module_exit(led_exit);

MODULE_LICENSE("GPL");