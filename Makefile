INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SizeFinder

SizeFinder_FILES = Tweak.xm
SizeFinder_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
