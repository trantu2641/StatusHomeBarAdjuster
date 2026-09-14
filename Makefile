ARCHS = arm64e
TARGET = iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk


TWEAK_NAME = StatusHomeBarAdjuster

StatusHomeBarAdjuster_FILES = Tweak.xm
StatusHomeBarAdjuster_CFLAGS = -fobjc-arc
StatusHomeBarAdjuster_FRAMEWORKS = UIKit Foundation
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
	Preferences/SHAStatusHomeBarAdjusterPrefs/Root.plist \
	Preferences/SHAStatusHomeBarAdjusterPrefs/SHAStatusHomeBarAdjusterPrefs.plist \
	Preferences/SHAStatusHomeBarAdjusterPrefs/Info.plist

SHAStatusHomeBarAdjusterPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
