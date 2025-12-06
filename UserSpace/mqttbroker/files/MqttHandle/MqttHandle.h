/* Definitions */
#include <stdint.h>

/* Types */
typedef enum
{
  INIT,
  IDLE,
  SENDING,
  SEND_SUCCESS
}MQTTHANDLE_DATASTATE;

/* Public variables */
extern MQTTHANDLE_DATASTATE MqttHandle_DataState;

/* Functions */
int MqttHandle_Init(void);
void MqttHandle_DeInit(void);
void MqttHandle_App(bool isWrite);