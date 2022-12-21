UNAME := $(shell uname -s)

AOM_GIT_DIR := https://aomedia.googlesource.com/aom
AOM_REVISION := 402e264b94fd74bdf66837da216b6251805b4ae4

HASHLINK_SRC=../hashlink
AOM_BUILD=aom_build

CFLAGS = -fPIC -I aom -I aom/third_party/libwebm -I aom/third_party/libyuv/include/
LFLAGS = -lhl $(AOM_BUILD)/libaom.a -lstdc++

SRC = webm.cc $(AOM_ADD)

YUV_DIR=$(AOM_BUILD)/CMakeFiles/yuv.dir
WEBM_DIR=$(AOM_BUILD)/CMakeFiles/webm.dir
SRC += \
        $(YUV_DIR)/third_party/libyuv/source/convert_argb.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/cpu_id.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/planar_functions.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/row_any.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/row_common.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/row_gcc.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/row_mips.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/row_neon.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/row_neon64.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/row_win.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/scale.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/scale_any.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/scale_common.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/scale_gcc.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/scale_mips.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/scale_neon.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/scale_neon64.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/scale_win.cc.o \
        $(YUV_DIR)/third_party/libyuv/source/scale_uv.cc.o \
        $(WEBM_DIR)/third_party/libwebm/mkvmuxer/mkvmuxer.cc.o \
        $(WEBM_DIR)/third_party/libwebm/mkvmuxer/mkvmuxerutil.cc.o \
        $(WEBM_DIR)/third_party/libwebm/mkvmuxer/mkvwriter.cc.o \
        $(WEBM_DIR)/third_party/libwebm/mkvparser/mkvparser.cc.o \
        $(WEBM_DIR)/third_party/libwebm/mkvparser/mkvreader.cc.o

OUTPUT=video.hdll

CMAKE_FLAGS = -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-fPIC" -DCMAKE_CXX_FLAGS="-fPIC"
ifdef VERBOSE
CMAKE_FLAGS += -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON 
endif

build: $(AOM_BUILD)
	$(CC) -shared $(CFLAGS) $(SRC) $(LFLAGS) -o $(OUTPUT)

aom:
	git clone $(AOM_GIT_DIR)
	cd aom && git checkout $(AOM_REVISION)

$(AOM_BUILD): aom
	mkdir -p $(AOM_BUILD)
	cd $(AOM_BUILD) && cmake ../aom $(CMAKE_FLAGS) && make
	touch $(AOM_BUILD)
