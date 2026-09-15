TARGET := iphone:clang:16.5:15.0
ARCHS := arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := Pixel1Photos

Pixel1Photos_FILES := Tweak.x
Pixel1Photos_CFLAGS := -fobjc-arc
Pixel1Photos_FRAMEWORKS := Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
