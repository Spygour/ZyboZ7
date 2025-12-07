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

typedef struct
{
  uint8_t type;
  uint8_t protocol_name_length[2];
  uint8_t protocolName[4];
  uint8_t protocol_level;
  uint8_t connect_flags;
  uint8_t keep_alive[2];
}MQTT_CONNECT_HEADER;


typedef struct
{
  const char* name;
  uint8_t size[2];
  uint16_t actl_size;
}MQTT_USERNAME;

typedef struct
{
  const char* name;
  uint8_t size[2];
  uint16_t actl_size;
}MQTT_PASSWORD;

typedef struct
{
  const char* name;
  uint8_t size[2];
  uint16_t actl_size;
}MQTT_CLIENT_ID;


/* MQTT PUBLISH TYPES */
typedef struct
{
	uint16_t dataRead;
	uint16_t dataRemain;
	uint16_t dataSize;
	uint8_t  writefail;
	uint8_t  readfail;
}MQTT_HANDLER_DATA_INFO;

/* Public variables */
extern MQTTHANDLE_DATASTATE MqttHandle_DataState;

/* Functions */
int MqttHandle_Init(void);
void MqttHandle_DeInit(void);
void MqttHandle_App(bool isWrite);
void MqttHandle_AppendPayload(float value);
void MqttHandle_ResetPayload(void);