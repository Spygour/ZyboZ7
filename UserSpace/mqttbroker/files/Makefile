APP = mqttbroker

# Source files
SRCS = mqttSender.c XadcHandle/XadcHandle.c AdcSonarHandle/AdcSonarHandle.c MqttHandle/MqttHandle.c

# Object files
APP_OBJS = $(patsubst %.c, %.o, $(SRCS))

# Compiler flags: add debug info and disable optimization
CFLAGS = -g -O0

# Link OpenSSL
LDLIBS = -lssl -lcrypto

all: build

build: $(APP)

# Compile each object file with debug symbols
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Link the application
$(APP): $(APP_OBJS)
	$(CC) $(CFLAGS) -o $@ $(APP_OBJS) $(LDFLAGS) $(LDLIBS)

clean:
	rm -f $(APP) $(APP_OBJS)
