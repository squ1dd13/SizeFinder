ARCHS = armv7 arm64
TARGET = iphone:clang: 11.2:7.0
GO_EASY_ON_ME = 1
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SizeFinder
SizeFinder_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
