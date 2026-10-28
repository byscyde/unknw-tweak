TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = Instagram

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = UNKNW

# Use the logos "internal" generator so hooks compile to self-contained
# Objective-C runtime calls (class_replaceMethod / method_setImplementation)
# instead of substrate's MSHookMessageEx. This drops the external
# CydiaSubstrate dependency entirely: UNKNW.dylib links only system frameworks,
# so there is no Substrate/Cydia-named image for Instagram's jailbreak scan to
# flag. Our own vendored fishhook (Sources/vendor) handles C-function rebinding.
UNKNW_LOGOS_DEFAULT_GENERATOR = internal

# Logos hooks (.x) and plain Objective-C (.m) from Sources/ and Sources/Features/.
# The template file uses .example so it is intentionally excluded.
UNKNW_FILES = $(wildcard Sources/*.x) $(wildcard Sources/*.m) $(wildcard Sources/Core/*.m) $(wildcard Sources/vendor/*.c) $(wildcard Sources/Features/*.x)
UNKNW_CFLAGS = -fobjc-arc -ISources
UNKNW_FRAMEWORKS = UIKit Foundation QuartzCore Photos AVFoundation Security

include $(THEOS_MAKE_PATH)/tweak.mk
