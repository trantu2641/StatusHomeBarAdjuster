ARCHS = arm64e
TARGET = iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk


TWEAK_NAME = StatusHomeBarAdjuster

StatusHomeBarAdjuster_FILES = Tweak.xm
StatusHomeBarAdjuster_CFLAGS = -fobjc-arc
StatusHomeBarAdjuster_FRAMEWORKS = UIKit Foundation QuartzCore
StatusHomeBarAdjuster_INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk


BUNDLE_NAME = SHAStatusHomeBarAdjusterPrefs

SHAStatusHomeBarAdjusterPrefs_FILES = \
	Preferences/RootListController.m

SHAStatusHomeBarAdjusterPrefs_CFLAGS = -fobjc-arc

SHAStatusHomeBarAdjusterPrefs_FRAMEWORKS = \
	UIKit \
	Foundation

SHAStatusHomeBarAdjusterPrefs_PRIVATE_FRAMEWORKS = \
	Preferences

SHAStatusHomeBarAdjusterPrefs_RESOURCE_FILES = \
	Preferences/Root.plist

SHAStatusHomeBarAdjusterPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk


after-stage::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences
	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceBundles/SHAStatusHomeBarAdjusterPrefs.bundle

	@cp Preferences/SHAStatusHomeBarAdjusterPrefs.plist \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SHAStatusHomeBarAdjusterPrefs.plist

	@cp Preferences/Info.plist \
		$(THEOS_STAGING_DIR)/Library/PreferenceBundles/SHAStatusHomeBarAdjusterPrefs.bundle/Info.plist
