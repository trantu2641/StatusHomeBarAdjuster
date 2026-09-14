ARCHS = arm64e
TARGET = iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StatusHomeBarAdjuster

StatusHomeBarAdjuster_FILES = Tweak.xm
StatusHomeBarAdjuster_CFLAGS = -fobjc-arc
StatusHomeBarAdjuster_FRAMEWORKS = UIKit Foundation CoreFoundation

StatusHomeBarAdjuster_INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = StatusHomeBarAdjusterPrefs

$(BUNDLE_NAME)_FILES = Preferences/StatusHomeBarAdjusterPrefs.bundle/RootListController.m
$(BUNDLE_NAME)_FRAMEWORKS = UIKit
$(BUNDLE_NAME)_PRIVATE_FRAMEWORKS = Preferences
$(BUNDLE_NAME)_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

after-stage::
	mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceBundles
	cp -R Preferences/StatusHomeBarAdjusterPrefs.bundle \
		$(THEOS_STAGING_DIR)/Library/PreferenceBundles/

	mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences
	cp Preferences/StatusHomeBarAdjusterPrefs.bundle/StatusHomeBarAdjusterPrefs.plist \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/
