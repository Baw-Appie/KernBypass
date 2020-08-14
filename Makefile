ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TOOL_NAME = changerootfs preparerootfs attach detach

LIB_DIR := lib

preparerootfs_FILES = preparerootfs.m
preparerootfs_CFLAGS = $(CFLAGS) -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function

changerootfs_FILES = changerootfs.m
changerootfs_CFLAGS = $(CFLAGS) -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function

attach_FILES = attach.m
attach_FRAMEWORKS = IOKit Foundation
attach_CFLAGS = $(CFLAGS) -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function

detach_FILES = detach.c
detach_FRAMEWORKS = IOKit Foundation
detach_CFLAGS = $(CFLAGS) -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function

SUBPROJECTS += zzzzzzzzznotifychroot
SUBPROJECTS += kernbypassd

ifdef USE_JELBREK_LIB
	preparerootfs_LDFLAGS = $(LIB_DIR)/jelbrekLib.dylib
	changerootfs_LDFLAGS = $(LIB_DIR)/jelbrekLib.dylib
endif

include $(THEOS_MAKE_PATH)/tool.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

ifdef USE_JELBREK_LIB
before-package::
	ldid -S./ent.plist $(THEOS_STAGING_DIR)/usr/lib/jelbrekLib.dylib
endif

before-package::
	mkdir -p $(THEOS_STAGING_DIR)/usr/lib/
	cp $(LIB_DIR)/jelbrekLib.dylib $(THEOS_STAGING_DIR)/usr/lib
	ldid -S./ent.plist $(THEOS_STAGING_DIR)/usr/bin/changerootfs
	ldid -S./ent.plist $(THEOS_STAGING_DIR)/usr/bin/preparerootfs	
	ldid -S./ent.plist $(THEOS_STAGING_DIR)/usr/bin/attach
	ldid -S./ent.plist $(THEOS_STAGING_DIR)/usr/bin/detach
# 	sudo chown -R root:wheel $(THEOS_STAGING_DIR)
	sudo chmod -R 755 $(THEOS_STAGING_DIR)
	sudo chmod 6755 $(THEOS_STAGING_DIR)/usr/bin/kernbypassd
	sudo chmod 666 $(THEOS_STAGING_DIR)/DEBIAN/control
    

include $(THEOS_MAKE_PATH)/aggregate.mk

after-package::
# 	make clean
	sudo rm -rf .theos/_

after-install::
# 	install.exec "killall backboardd"