LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := patchlcs.c
LOCAL_MODULE := patchlcs
LOCAL_MODULE_TAGS := optional

include $(BUILD_HOST_EXECUTABLE)
PATCHLCS := $(LOCAL_BUILT_MODULE)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := toggleshutter.c
LOCAL_MODULE := toggleshutter
LOCAL_MODULE_TAGS := optional
LOCAL_SHARED_LIBRARIES := libcutils
include $(BUILD_EXECUTABLE)

# FIXME this is ugly and the .patched.so should reside somewhere in out/
vendor/samsung/aries-common/proprietary/libcameraservice.patched.so: $(PATCHLCS) vendor/samsung/aries-common/proprietary/libcameraservice.so
	$(PATCHLCS) vendor/samsung/aries-common/proprietary/libcameraservice.so $@
