/* Include files here */
#include "MqttHandle.h"
#include <arpa/inet.h>
#include <fcntl.h>
#include <netdb.h>
#include <openssl/err.h>
#include <openssl/ssl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

/* Definitions */
#define MQTT_ANSWER_BYTES_4 (uint16_t)4u

#define MQTT_CONNECT_TYPE (uint8_t)0x10U
#define MQTT_CONNACK_TYPE (uint8_t)0x20U
#define MQTT_CONNECT_HEADER_DEFAULT_LEN (uint8_t)10U
#define MQTT_LEN_INDEX_DEFAULT (uint8_t)1u
#define MQTT_LENGTH (uint16_t)4U
#define MQTT_PROTOCOL_LEVEL (uint8_t)4U
#define MQTT_CONNECT_FLAG_FULL_CLEAN (uint8_t)0xC2U
#define MQTT_KEEPALIVE_60SECS (uint16_t)60U

#define MQTT_PUBLISH_TYPE_QOS0 (uint8_t)0X30
#define MQTT_PUBLISH_TYPE_QOS1 (uint8_t)0X32
#define MQTT_PUBLISH_TYPE_QOS2 (uint8_t)0X34

#define MQTT_PUBACK_TYPE (uint8_t)0x40

#define MQTT_PINGREQ_TYPE (uint8_t)0xC0
#define MQTT_PINGRESP_TYPE (uint8_t)0xD0

typedef struct
{
    char* payload;
    uint16_t size;
} MQTT_PAYLOAD;

typedef struct
{
    uint8_t Type;
    uint16_t PacketId;
    uint16_t PayloadSize;
} MQTT_PUBLISH_CFG;

/* Types */
typedef enum
{
    CONNECT,
    CONNACK,
    PINGREQ,
    PINGRESP,
    PUBLISH,
    PUBACK,
    WRITE,
    READ
} MQTTHANDLE_STATE;

/* --- Static/global variables --- */
static SSL_CTX* ssl_ctx = NULL;                     // OpenSSL context
static SSL* ssl_handle = NULL;                      // SSL session
static int adafruitIo_sock = -1;                    // TCP socket
static const char* server_host = "io.adafruit.com"; // Server hostname
static const int server_port = 8883;                // MQTT port

/* MQTT DATA */
/* THS WILL BE EDITED BY A SCRIPT I GUESS */
const char mqtt_clientName[] = "zyboClient";
const char mqtt_userName[] = "MyName";
const char mqtt_password[] = "MyPass";
const char mqtt_protocolAsci[] = "MQTT";
/* The server CA certificate as a string/array (PEM format) */
static const char server_cert[] = "-----BEGIN CERTIFICATE-----\n"
                                  "MyCert\n"
                                  "-----END CERTIFICATE-----\n";

static char MqttTopic[] = "MyTopic";

static char publishpayload[128];

static MQTT_PAYLOAD MqttPayload = {publishpayload, 0};

/* MQTT STATIC VARIABLES used for the  initialization and connection */
static MQTT_CLIENT_ID mqtt_client;

static MQTT_USERNAME mqtt_user;

static MQTT_PASSWORD mqtt_pass;

/* THIS NEEDS TO SPECIFIED*/

MQTTHANDLE_DATASTATE MqttHandle_DataState = INIT;

static unsigned char mqtt_buffer[1500];

static MQTT_CONNECT_HEADER mqtt_connectHeader = {
    MQTT_CONNECT_TYPE, {0x0, 0x4}, {'M', 'Q', 'T', 'T'}, MQTT_PROTOCOL_LEVEL, MQTT_CONNECT_FLAG_FULL_CLEAN,
    {0x0, 0x3C} /* 60 Seconds for now */
};

static MQTT_PUBLISH_CFG mqtt_publishCfg = {MQTT_PUBLISH_TYPE_QOS1, 0U, 0U};
static MQTTHANDLE_STATE mqtt_state;
static MQTTHANDLE_STATE mqtt_nextstate;
static MQTT_HANDLER_DATA_INFO mqtt_DataInfo;

void MqttHandle_AppendPayload(float value)
{
    uint16_t index = MqttPayload.size;
    MqttPayload.size += snprintf(&publishpayload[index], sizeof(publishpayload), "%.3f", value);
}

void MqttHandle_ResetPayload(void) { MqttPayload.size = 0U; }

static int ssl_init(void)
{
    int ret = 0;
    BIO* cert_bio = NULL;
    X509* cert = NULL;

    /* Initialize OpenSSL (older APIs — acceptable for many builds) */
    SSL_library_init();
    SSL_load_error_strings();
    OpenSSL_add_all_algorithms();

    /* Create SSL context */
    ssl_ctx = SSL_CTX_new(TLS_client_method());
    if (!ssl_ctx) {
        fprintf(stderr, "SSL_CTX_new failed\n");
        return -1;
    }

    SSL_CTX_set_min_proto_version(ssl_ctx, TLS1_2_VERSION);
    SSL_CTX_set_options(ssl_ctx, SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3);

    /* If you need the TLS1.2 cipher specifically: */
    if (!SSL_CTX_set_cipher_list(ssl_ctx, "ECDHE-RSA-AES256-GCM-SHA384")) {
        fprintf(stderr, "Warning: setting cipher list failed\n");
    }

    SSL_CTX_set_verify_depth(ssl_ctx, 5);

    X509_VERIFY_PARAM* vparam = SSL_CTX_get0_param(ssl_ctx);
    X509_VERIFY_PARAM_set_hostflags(vparam, X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS);
    if (!X509_VERIFY_PARAM_set1_host(vparam, server_host, 0)) {
        fprintf(stderr, "Warning: X509_VERIFY_PARAM_set1_host failed\n");
    }

    /* Preferred: let OpenSSL use default paths (system CA bundle) */
    if (!SSL_CTX_set_default_verify_paths(ssl_ctx)) {
        /* Not fatal — you can fall back to loading memory CA */
        fprintf(stderr, "Warning: SSL_CTX_set_default_verify_paths failed\n");
    }

    /* If you still want to load CA(s) from memory (server_cert contains one or several PEM certs): */
    cert_bio = BIO_new_mem_buf((void*)server_cert, (int)strlen(server_cert));
    if (!cert_bio) {
        fprintf(stderr, "BIO_new_mem_buf failed\n");
        SSL_CTX_free(ssl_ctx);
        return -1;
    }

    X509_STORE* store = SSL_CTX_get_cert_store(ssl_ctx);
    while ((cert = PEM_read_bio_X509(cert_bio, NULL, 0, NULL)) != NULL) {
        if (!X509_STORE_add_cert(store, cert)) {
            /* X509_STORE_add_cert returns 0 on error (often duplicate) */
            unsigned long err = ERR_get_error();
            /* ignore duplicates, but you can log if it's a different error */
            if (ERR_REASON_ERROR_STRING(err)) {
                /* optional: log reason */
            }
        }
        X509_free(cert);
    }
    BIO_free(cert_bio);

    /* Enforce verification */
    SSL_CTX_set_verify(ssl_ctx, SSL_VERIFY_PEER, NULL);

    return ret;
}

static int tcp_connect(void)
{
    struct sockaddr_in server_addr;
    struct hostent* host;

    adafruitIo_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (adafruitIo_sock < 0)
    {
        perror("socket");
        return -1;
    }

    host = gethostbyname(server_host);
    if (!host)
    {
        fprintf(stderr, "gethostbyname failed\n");
        close(adafruitIo_sock);
        return -1;
    }

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(server_port);
    memcpy(&server_addr.sin_addr.s_addr, host->h_addr, host->h_length);

    if (connect(adafruitIo_sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0)
    {
        perror("connect");
        close(adafruitIo_sock);
        return -1;
    }

    return 0;
}

static int ssl_handshake(void)
{
    ssl_handle = SSL_new(ssl_ctx);
    if (!ssl_handle) {
        fprintf(stderr, "SSL_new failed\n");
        return -1;
    }

    SSL_set_fd(ssl_handle, adafruitIo_sock);

    if (!SSL_set_tlsext_host_name(ssl_handle, server_host)) {
        fprintf(stderr, "SNI set failed\n");
    }

    if (SSL_connect(ssl_handle) <= 0) {
        fprintf(stderr, "SSL_connect failed\n");
        ERR_print_errors_fp(stderr);
        return -1;
    }

    long vr = SSL_get_verify_result(ssl_handle);
    if (vr != X509_V_OK) {
        fprintf(stderr, "Certificate verify failed: %s\n", X509_verify_cert_error_string(vr));
        /* optionally cleanup ssl_handle */
        return -1;
    }

    printf("Connected with %s encryption\n", SSL_get_cipher(ssl_handle));
    
    return 0;
}

static int ssl_write_data(const char* buf, int len)
{
    if (!ssl_handle)
        return -1;
    return SSL_write(ssl_handle, buf, len);
}

static int ssl_read_data(char* buf, int max_len)
{
    if (!ssl_handle)
        return -1;
    return SSL_read(ssl_handle, buf, max_len);
}

static void MqttHandle_StackInit(void)
{
    /* Initialize the password, user and client */
    mqtt_client.actl_size = strlen(mqtt_clientName);
    mqtt_client.name = mqtt_clientName;
    mqtt_client.size[0] = (uint8_t)(mqtt_client.actl_size >> 8);
    mqtt_client.size[1] = (uint8_t)(mqtt_client.actl_size & 0x00FF);

    mqtt_user.actl_size = strlen(mqtt_userName);
    mqtt_user.name = mqtt_userName;
    mqtt_user.size[0] = (uint8_t)(mqtt_user.actl_size >> 8);
    mqtt_user.size[1] = (uint8_t)(mqtt_user.actl_size & 0x00FF);

    mqtt_pass.actl_size = strlen(mqtt_password);
    mqtt_pass.name = mqtt_password;
    mqtt_pass.size[0] = (uint8_t)(mqtt_pass.actl_size >> 8);
    mqtt_pass.size[1] = (uint8_t)(mqtt_pass.actl_size & 0x00FF);
}

int MqttHandle_Init(void)
{
    mqtt_state = CONNECT;
    mqtt_nextstate = CONNECT;
    MqttHandle_DataState = INIT;
    MqttHandle_StackInit();
    int status = 0u;
    /* Initialize the ssl*/
    status |= ssl_init();

    status |= tcp_connect();

    status |= ssl_handshake();

    return status;
}

void MqttHandle_DeInit(void)
{
    if (ssl_handle)
    {
        SSL_shutdown(ssl_handle);
        SSL_free(ssl_handle);
        ssl_handle = NULL;
    }
    if (sock >= 0)
    {
        close(sock);
        sock = -1;
    }
    if (ssl_ctx)
    {
        SSL_CTX_free(ssl_ctx);
        ssl_ctx = NULL;
    }
}

/* MQTT FUNCTIONS */
static uint32_t SSL_Mqtt_Connect_CreateMessage(unsigned char* buf)
{
    uint32_t len_prv =
        MQTT_CONNECT_HEADER_DEFAULT_LEN + mqtt_client.actl_size + 2 + mqtt_user.actl_size + 2 + mqtt_pass.actl_size + 2;
    uint8_t lengthBytesNum = 0;

    *buf++ = mqtt_connectHeader.type;
    /* this will be the len */
    uint32_t x = len_prv;
    do
    {
        uint8_t encoded = x % 128;
        x /= 128;
        if (x > 0)
            encoded |= 0x80;
        *buf++ = encoded;
        lengthBytesNum++;
    } while (x > 0);

    memcpy(buf, mqtt_connectHeader.protocol_name_length, 2);
    buf += 2;
    memcpy(buf, mqtt_connectHeader.protocolName, 4);
    buf += 4;
    *buf++ = mqtt_connectHeader.protocol_level;
    *buf++ = mqtt_connectHeader.connect_flags;
    memcpy(buf, mqtt_connectHeader.keep_alive, 2);
    buf += 2;

    memcpy(buf, mqtt_client.size, 2);
    buf += 2;
    memcpy(buf, mqtt_client.name, mqtt_client.actl_size);
    buf += mqtt_client.actl_size;

    memcpy(buf, mqtt_user.size, 2);
    buf += 2;
    memcpy(buf, mqtt_user.name, mqtt_user.actl_size);
    buf += mqtt_user.actl_size;

    memcpy(buf, mqtt_pass.size, 2);
    buf += 2;
    memcpy(buf, mqtt_pass.name, mqtt_pass.actl_size);
    buf += mqtt_pass.actl_size;

    len_prv += lengthBytesNum + 1u;

    return len_prv;
}

static bool SSL_Mqtt_Connack(unsigned char* buf)
{
    return ((buf[0] == MQTT_CONNACK_TYPE) /* Connack */
            && (buf[1] == 0x02)           /* length 2 */
            && (buf[2] == 0x00));         /* new session */
}

static uint32_t SSL_Mqtt_Publish_CreatePacket(unsigned char* buf, MQTT_PAYLOAD* payload, char* topic, uint16_t topicLen)
{
    uint32_t len_prv = 0u;
    uint8_t lengthBytesNum = 0;
    mqtt_publishCfg.PayloadSize = payload->size;
    len_prv =
        mqtt_publishCfg.PayloadSize + topicLen + 2 + 2; /* 2 bytes payload, 2 bytes topic and 2 bytes identifier */

    /* Store the type */
    *buf++ = mqtt_publishCfg.Type;

    /* Evaluate how big is the size */
    // MQTT Variable-Length Remaining Length
    uint32_t x = len_prv;
    do
    {
        uint8_t encoded = x % 128;
        x /= 128;
        if (x > 0)
            encoded |= 0x80;
        *buf++ = encoded;
        lengthBytesNum++;
    } while (x > 0);

    /* Store the topic len and then the topic */
    *buf++ = (uint8_t)(topicLen >> 8);
    *buf++ = (uint8_t)(topicLen);
    memcpy(buf, topic, (int)topicLen);
    buf += topicLen;

    /* Store the packet id and after that increase it*/
    *buf++ = (uint8_t)(mqtt_publishCfg.PacketId >> 8);
    *buf++ = (uint8_t)(mqtt_publishCfg.PacketId);

    /* Store the payload */
    memcpy(buf, payload->payload, mqtt_publishCfg.PayloadSize);
    buf += mqtt_publishCfg.PayloadSize;

    /* Increase to get the type and the len */
    len_prv += 1u + lengthBytesNum;
    return len_prv;
}

static bool SSL_Mqtt_Puback(uint8_t* buf)
{
    bool ret = true;
    if (mqtt_publishCfg.Type != MQTT_PUBLISH_TYPE_QOS0)
    {
        ret =
            ((buf[0] == MQTT_PUBACK_TYPE) && (buf[1] == 0x02) && (buf[2] == (uint8_t)(mqtt_publishCfg.PacketId >> 8)) &&
             (buf[3] == (uint8_t)(mqtt_publishCfg.PacketId & 0x00FF)));
    }
    else
    {
        ret = true;
    }
    /* Increase the packetId for the next message */
    mqtt_publishCfg.PacketId++;

    return ret;
}

static uint8_t SSL_Mqtt_PingReq_Create(unsigned char* buf)
{
    buf[0] = MQTT_PINGREQ_TYPE; // PINGREQ type (1100 0000)
    buf[1] = 0x00;              // Remaining length = 0
    return 2;                   // Always 2 bytes
}

static bool SSL_Mqtt_PingResp_Received(unsigned char* buf, uint16_t len)
{
    // PINGRESP type is 0xD0, remaining length is 0
    return ((len == 2) && (buf[0] == MQTT_PINGRESP_TYPE) && (buf[1] == 0x00));
}

static bool SSL_MqttWriteHandler(unsigned char* buf)
{
    bool status_success = false;
    uint16_t bufIdx = mqtt_DataInfo.dataSize - mqtt_DataInfo.dataRemain;
    /* Here we check if we sent all the data */
    int ret = ssl_write_data(&buf[bufIdx], mqtt_DataInfo.dataRemain);
    if (ret > 0)
    {
        if (mqtt_DataInfo.dataRemain <= ret)
        {
            mqtt_DataInfo.dataRemain = 0;
            status_success = true;
        }
        else
        {
            mqtt_DataInfo.dataRemain -= ret;
        }
    }
    else if (ret == SSL_ERROR_WANT_READ || ret == SSL_ERROR_WANT_WRITE)
    {
        mqtt_DataInfo.writefail++;
    }
    else
    {
        /* Do nothing there please */
    }
    return status_success;
}

static bool SSL_MqttReadHandler(unsigned char* buf)
{
    bool status_success = false;
    uint16_t bufIdx = mqtt_DataInfo.dataSize - mqtt_DataInfo.dataRemain;
    /* Here we check if we sent all the data */
    int ret = ssl_read_data(&buf[bufIdx], mqtt_DataInfo.dataRemain);
    if (ret > 0)
    {
        if (mqtt_DataInfo.dataRemain <= ret)
        {
            mqtt_DataInfo.dataRemain = 0;
            status_success = true;
        }
        else
        {
            mqtt_DataInfo.dataRemain -= ret;
        }
    }
    else if (ret == SSL_ERROR_WANT_READ || ret == SSL_ERROR_WANT_WRITE)
    {
        mqtt_DataInfo.readfail++;
    }
    else
    {
        /* Do nothing there please */
    }
    return status_success;
}

void MqttHandle_App(bool isWrite)
{
    switch (mqtt_state)
    {
    case CONNECT:
    {
        mqtt_DataInfo.dataRemain = SSL_Mqtt_Connect_CreateMessage(&mqtt_buffer[0]);
        /* Store the data that we are about to send */
        mqtt_DataInfo.dataSize = mqtt_DataInfo.dataRemain;
        mqtt_state = WRITE;
        mqtt_DataInfo.dataRead = 4;
        mqtt_nextstate = CONNACK;
    }
    break;

    case CONNACK:
    {
        if (SSL_Mqtt_Connack(&mqtt_buffer[0]))
        {
            MqttHandle_DataState = IDLE;
            mqtt_state = PINGREQ;
        }
        else
        {
            mqtt_state = CONNECT;
        }
    }
    break;

    case PINGREQ:
    {
        if (isWrite)
        {
            mqtt_state = PUBLISH;
        }
        else
        {
            mqtt_DataInfo.dataRemain = SSL_Mqtt_PingReq_Create(&mqtt_buffer[0]);
            mqtt_DataInfo.dataSize = mqtt_DataInfo.dataRemain;
            mqtt_state = WRITE;
            mqtt_DataInfo.dataRead = 2;
            mqtt_nextstate = PINGRESP;
        }
    }
    break;

    case PINGRESP:
    {
        if (SSL_Mqtt_PingResp_Received(&mqtt_buffer[0], mqtt_DataInfo.dataRead))
        {
            mqtt_state = PINGREQ;
            mqtt_nextstate = PINGRESP;
        }
        else
        {
            mqtt_state = CONNECT;
        }
    }
    break;

    case PUBLISH:
    {
        MqttHandle_DataState = SENDING;
        mqtt_DataInfo.dataRemain =
            SSL_Mqtt_Publish_CreatePacket(&mqtt_buffer[0], &MqttPayload, MqttTopic, strlen(MqttTopic));
        mqtt_DataInfo.dataSize = mqtt_DataInfo.dataRemain;
        mqtt_state = WRITE;
        mqtt_DataInfo.dataRead = 4;
        mqtt_nextstate = PUBACK;
    }
    break;

    case PUBACK:
    {
        if (SSL_Mqtt_Puback(&mqtt_buffer[0]))
        {
            MqttHandle_DataState = IDLE;
            mqtt_state = PINGREQ;
        }
        else
        {
            mqtt_state = CONNECT;
        }
    }
    break;

    case WRITE:
    {
        if (SSL_MqttWriteHandler(&mqtt_buffer[0]))
        {
            /* WRITE IS FINISHED READ ANSWER */
            mqtt_DataInfo.dataSize = mqtt_DataInfo.dataRead;
            mqtt_DataInfo.dataRemain = mqtt_DataInfo.dataRead;
            mqtt_state = READ;
        }
    }
    break;

    case READ:
    {
        if (SSL_MqttReadHandler(&mqtt_buffer[0]))
        {
            mqtt_state = mqtt_nextstate;
        }
    }
    break;

    default:
    {
        break;
    }
    }
}
