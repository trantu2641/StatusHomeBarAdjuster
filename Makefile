ARCHS = arm64e
TARGET = iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk


# ==========================================
# TWEAK
# ==========================================

TWEAK_NAME = StatusHomeBarAdjuster

StatusHomeBarAdjuster_FILES = Tweak.xm
StatusHomeBarAdjuster_CFLAGS = -fobjc-arc
StatusHomeBarAdjuster_FRAMEWORKS = UIKit Foundation CoreFoundation

StatusHomeBarAdjuster_INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk


# ==========================================
# PREFERENCE BUNDLE
# ==========================================

BUNDLE_NAME = StatusHomeBarAdjusterPrefs

StatusHomeBarAdjusterPrefs_FILES = \
    Preferences/RootListController.m

StatusHomeBarAdjusterPrefs_CFLAGS = -fobjc-arc

StatusHomeBarAdjusterPrefs_FRAMEWORKS = UIKit

StatusHomeBarAdjusterPrefs_PRIVATE_FRAMEWORKS = Preferences

StatusHomeBarAdjusterPrefs_RESOURCE_FILES = \
    Preferences/StatusHomeBarAdjusterPrefs/Info.plist \
    Preferences/StatusHomeBarAdjusterPrefs/Root.plist

StatusHomeBarAdjusterPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk


# ==========================================
# PREFERENCE LOADER
# ==========================================

after-stage::
	@mkdir -p \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences

	@cp \
		Preferences/StatusHomeBarAdjusterPrefs.plist \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/
