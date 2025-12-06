#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netdb.h>
#include <fcntl.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include "MqttHandle.h"

/* --- Static/global variables --- */
static SSL_CTX *ssl_ctx = NULL;       // OpenSSL context
static SSL *ssl_handle = NULL;        // SSL session
static int sock = -1;                 // TCP socket
static const char *server_host = "io.adafruit.com";  // Server hostname
static const int server_port = 8883;                // MQTT port
MQTTHANDLE_DATASTATE MqttHandle_DataState = INIT;

/* The server CA certificate as a string/array (PEM format) */
static const char server_cert[] =
"-----BEGIN CERTIFICATE-----\n"
"...your certificate PEM contents here...\n"
"-----END CERTIFICATE-----\n";

static int ssl_init(void)
{
  int ret = 0;
  BIO *cert_bio = NULL;
  X509 *cert = NULL;

  /* Initialize OpenSSL */
  SSL_library_init();
  SSL_load_error_strings();
  OpenSSL_add_all_algorithms();

  /* Create SSL context */
  ssl_ctx = SSL_CTX_new(TLS_client_method());
  if (!ssl_ctx) {
      fprintf(stderr, "SSL_CTX_new failed\n");
      return -1;
  }

  /* Load the server CA certificate from memory */
  cert_bio = BIO_new_mem_buf(server_cert, -1);
  if (!cert_bio) {
      fprintf(stderr, "BIO_new_mem_buf failed\n");
      return -1;
  }

  cert = PEM_read_bio_X509(cert_bio, NULL, 0, NULL);
  if (!cert) {
      fprintf(stderr, "PEM_read_bio_X509 failed\n");
      BIO_free(cert_bio);
      return -1;
  }

  /* Set certificate as trusted CA */
  X509_STORE_add_cert(SSL_CTX_get_cert_store(ssl_ctx), cert);

  BIO_free(cert_bio);
  X509_free(cert);

  /* Optional: enforce verification */
  SSL_CTX_set_verify(ssl_ctx, SSL_VERIFY_PEER, NULL);

  return ret;
}

static int tcp_connect(void)
{
    struct sockaddr_in server_addr;
    struct hostent *host;

    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket");
        return -1;
    }

    host = gethostbyname(server_host);
    if (!host) {
        fprintf(stderr, "gethostbyname failed\n");
        close(sock);
        return -1;
    }

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(server_port);
    memcpy(&server_addr.sin_addr.s_addr, host->h_addr, host->h_length);

    if (connect(sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        perror("connect");
        close(sock);
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

    /* Attach SSL to the existing socket */
    SSL_set_fd(ssl_handle, sock);

    if (SSL_connect(ssl_handle) <= 0) {
        fprintf(stderr, "SSL_connect failed\n");
        ERR_print_errors_fp(stderr);
        return -1;
    }

    printf("Connected with %s encryption\n", SSL_get_cipher(ssl_handle));
    return 0;
}

static int ssl_write_data(const char *buf, int len)
{
    if (!ssl_handle) return -1;
    return SSL_write(ssl_handle, buf, len);
}

static int ssl_read_data(char *buf, int max_len)
{
    if (!ssl_handle) return -1;
    return SSL_read(ssl_handle, buf, max_len);
}

int MqttHandle_Init(void)
{
  int status = 0u;
  /* Initialize the ssl*/
  status |= ssl_init();

  status |= tcp_connect();

  status |= ssl_handshake();

  return status;
}

void MqttHandle_DeInit(void)
{
    if (ssl_handle) {
        SSL_shutdown(ssl_handle);
        SSL_free(ssl_handle);
        ssl_handle = NULL;
    }
    if (sock >= 0) {
        close(sock);
        sock = -1;
    }
    if (ssl_ctx) {
        SSL_CTX_free(ssl_ctx);
        ssl_ctx = NULL;
    }
}

void MqttHandle_App(bool isWrite)
{
    
}
