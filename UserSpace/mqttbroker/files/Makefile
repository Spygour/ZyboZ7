APP = mqttbroker

# Source files
SRCS = mqttSender.c XadcHandle/XadcHandle.c AdcSonarHandle/AdcSonarHandle.c

# Object files
APP_OBJS = $(patsubst %.c, %.o, $(SRCS))

all: build

build: $(APP)

$(APP): $(APP_OBJS)
	$(CC) -o $@ $(APP_OBJS) $(LDFLAGS) $(LDLIBS)
clean:
	rm -f $(APP) *.o

