ARCHS = arm64e
TARGET = iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StatusHomeBarAdjuster

StatusHomeBarAdjuster_FILES = Tweak.xm
StatusHomeBarAdjuster_CFLAGS = -fobjc-arc
StatusHomeBarAdjuster_FRAMEWORKS = UIKit Foundation CoreFoundation
StatusHomeBarAdjuster_INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk

after-stage::
	$(ECHO_NOTHING) "Copying preference bundle..." $(ECHO_END)
	mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceBundles
	cp -R Preferences/StatusHomeBarAdjuster.bundle \
		$(THEOS_STAGING_DIR)/Library/PreferenceBundles/
