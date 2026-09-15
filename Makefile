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

SHAStatusHomeBarAdjusterPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk


after-stage::
	@echo "==> Installing PreferenceLoader files..."

	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences

	@cp Preferences/SHAStatusHomeBarAdjusterPrefs.plist \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SHAStatusHomeBarAdjusterPrefs.plist

	@echo "==> Creating Preference Bundle Info.plist..."

	@mkdir -p \
		$(THEOS_STAGING_DIR)/Library/PreferenceBundles/SHAStatusHomeBarAdjusterPrefs.bundle

	@cat > \
		$(THEOS_STAGING_DIR)/Library/PreferenceBundles/SHAStatusHomeBarAdjusterPrefs.bundle/Info.plist <<'EOF'
{
	CFBundleDevelopmentRegion = en;
	CFBundleDisplayName = "Status & Home Bar Adjuster";
	CFBundleExecutable = "SHAStatusHomeBarAdjusterPrefs";
	CFBundleIdentifier = "com.congtu.sha.statushomebaradjusterprefs";
	CFBundleInfoDictionaryVersion = "6.0";
	CFBundleName = "SHAStatusHomeBarAdjusterPrefs";
	CFBundlePackageType = "BNDL";
	CFBundleShortVersionString = "1.0.5";
	CFBundleVersion = "1";
	NSPrincipalClass = "SHAStatusHomeBarAdjusterController";
}
EOF

	@echo "==> Preference Bundle staged successfully."
