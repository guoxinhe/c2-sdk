#NAND_FLASH=N

#next 4 are added by my localmachine.
SW_MEDIA_PATH=/local/hguo/tools
BUILD_TARGET=TARGET_LINUX_C2
TARGET_ARCH=TANGO
BUILD=RELEASE

ARCH=C2
C2_SW_MEDIA_INCLUDE=$(SW_MEDIA_PATH)/$(BUILD_TARGET)_$(TARGET_ARCH)_$(BUILD)/include
C2_SW_MEDIA_LIBS=-L$(SW_MEDIA_PATH)/$(BUILD_TARGET)_$(TARGET_ARCH)_$(BUILD)/lib -lColorConvertC2 -lOsdAntiFlickerJazzBC2

ifeq ($(BUILD_TARGET),TARGET_LINUX_X86)
COMPILE_CROSS=
else
COMPILE_CROSS=c2-linux-uclibc-
endif
CC=$(COMPILE_CROSS)g++
AR=$(COMPILE_CROSS)ar

#ifeq ($(NAND_FLASH), Y)
#SOURCES = c2Update.cpp 
#OBJECTS = c2Update.o  
#else
SOURCES = 16mUpdate.cpp c2Update.cpp c2OsdApi.cpp
OBJECTS = 16mUpdate.o c2Update.o c2OsdApi.o
#endif

TARGET = c2Update
CFLAGS += -pthread -Wall -mgrouped -I. -I$(C2_SW_MEDIA_INCLUDE) -DBUILD_TARGET_HAS_LINUX_THREADS=1 -DBUILD_TARGET_HAS_POSIX_THREADS=1
#ifeq ($(NAND_FLASH), N)
#CFLAGS += -DSPI_FLASH_UPDATE 
#endif

LDLIBS += -lpthread $(C2_SW_MEDIA_LIBS) -lframework-common -lframework-c2 -lframework-common -static

.cpp.o:
	$(CC) -c $(CFLAGS) $(CPPFLAGS) -o $@ $<

$(TARGET): $(OBJECTS)
	$(CC) $^ -o $@ $(LDLIBS)

bees: bees.cpp
	$(CC) $^ -lpthread -I/home/hguo/kernel/linux-2.6/include -o $@ #$(LDLIBS)
	g++   $^ -lpthread -DX86 -o $@.x86

all: $(TARGET)

clean: 
	rm -rf $(OBJECTS) $(TARGET)  bees bees.x86

shit:
	echo $(SW_MEDIA_PATH) $(BUILD_TARGET) $(TARGET_ARCH) $(BUILD)
