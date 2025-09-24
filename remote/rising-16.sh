#!/bin/bash

source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc

cd /tmp/src/android/

set -v

# Template helper variables
PACKAGE_NAME=RisingOS_Revived-8
VARIANT_NAME=user
BUILD_TYPE=vanilla
DEVICE_BRANCH=lineage-23.0
VENDOR_BRANCH=lineage-23.0
XIAOMI_BRANCH=lineage-23.0
GENOTA_ARG_1="rising"
GENOTA_ARG_2="8"
REPO_PARAMS=" --git-lfs --depth=1 --no-tags --no-clone-bundle"
REPO_URL="-u https://github.com/RisingOS-Revived/android -b sixteen-los $REPO_PARAMS"
SECONDS=0
if echo $@ | grep "JJ_SPEC:" ; then export JJ_SPEC=`echo $@ | cut -d ":" -f 2` ; fi
TG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

# Send push notifications
notify_send() {
   local MSG
   MSG="$@"
   curl -s -X POST $TG_URL -d chat_id=$TG_CID -d text="$MSG `env LC_ALL="" TZ=Africa/Harare LC_TIME="C.UTF-8" date`. JJ_SPEC:$JJ_SPEC" > /dev/null 2>&1
   curl -s -d "$MSG `env LC_ALL="" TZ=Africa/Harare LC_TIME="C.UTF-8" date`. JJ_SPEC:$JJ_SPEC" "ntfy.sh/$NTFYSUB" > /dev/null 2>&1
}

notify_send "Build $PACKAGE_NAME on crave.io started."

# Always cleanup
cleanup_self () {
   cd /tmp/src/android/
   rm -rf vendor/lineage-priv/keys vendor/lineage-priv priv-keys .config/b2/ /home/admin/.config/b2/
   cd packages/apps/Updater/ && git reset --hard && cd ../../../
   cd packages/modules/Connectivity/ && git reset --hard && cd ../../../
   rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
   rm -rf hardware/xiaomi/ device/xiaomi/chime/ vendor/xiaomi/chime/ kernel/xiaomi/chime/
   rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml* builder.sh goupload.sh GOFILE.txt
   rm -rf /tmp/android-certs* /home/admin/venv/ custom_scripts/
   cd /home/admin
   rm -rf .tdl LICENSE README.md README_zh.md tdl tdl_key tdl_Linux_64bit.tar.gz* venv tdl.zip tdl_Linux.tgz tdl.sh
   cd /tmp/src/android/
}

# Better than ' || exit 1 '
check_fail () {
   if [ $? -ne 0 ]; then 
       if ls out/target/product/chime/$PACKAGE_NAME*.zip; then
   	  notify_send "Build $PACKAGE_NAME on crave.io softfailed."
          echo weird. build failed but OTA package exists.
          echo softfail > result.txt
	  cleanup_self
          exit 1
       else
          notify_send "Build $PACKAGE_NAME on crave.io failed."
	  echo "oh no. script failed"
          curl -L -F document=@"out/error.log" -F caption="error log" -F chat_id="$TG_CID" -X POST https://api.telegram.org/bot$TG_TOKEN/sendDocument > /dev/null 2>&1
          cleanup_self
	  echo fail > result.txt
          exit 1 
       fi
   fi
}

# repo sync. or not.
if echo "$@" | grep resume; then
   echo "resuming"
else
   rm -rf .repo/manifests*
   repo init $REPO_URL  ; check_fail
   cleanup_self
   /opt/crave/resync.sh
fi

# Download trees
rm -rf kernel/xiaomi/chime/ vendor/xiaomi/chime/ device/xiaomi/chime/ hardware/xiaomi/
rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
curl -o kernel.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/kernel-prebuilt-perf-valeryn.tar.xz" ; check_fail
tar xf kernel.tar.xz ; check_fail
rm -f kernel.tar.xz
curl -o lineage-22.1.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/lineage-22.1.tar.xz" ; check_fail
tar xf lineage-22.1.tar.xz ; check_fail
rm -f lineage-22.1.tar.xz
curl -o toolchain.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/toolchain.tar.xz" ; check_fail
tar xf toolchain.tar.xz ; check_fail
rm -f toolchain.tar.xz
git clone https://github.com/Joe7500/device_xiaomi_chime.git -b $DEVICE_BRANCH device/xiaomi/chime ; check_fail
git clone https://github.com/Joe7500/vendor_xiaomi_chime.git -b $VENDOR_BRANCH vendor/xiaomi/chime ; check_fail
git clone https://github.com/LineageOS/android_hardware_xiaomi -b $XIAOMI_BRANCH hardware/xiaomi ; check_fail

# Setup AOSP source 
patch -f -p 1 < wfdservice.rc.patch ; check_fail
cd packages/modules/Connectivity/ && git reset --hard && cd ../../../
patch -f -p 1 < InterfaceController.java.patch ; check_fail
rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml.*
rm -f vendor/xiaomi/chime/proprietary/system_ext/etc/init/wfdservice.rc.rej
rm -f packages/modules/Connectivity/staticlibs/device/com/android/net/module/util/ip/InterfaceController.java.rej

cd packages/apps/Updater/ && git reset --hard && cd ../../../
cp packages/apps/Updater/app/src/main/res/values/strings.xml strings.xml.backup.orig.txt
cat strings.xml.backup.orig.txt | sed -e 's#RisingOS-Revived/official_devices/.*GAPPS.*json#Joe7500/Builds/main/rising-rev-8-gapps-chime.json#g' > strings.xml.new.txt
mv strings.xml.new.txt strings.xml.backup.orig.txt
cat strings.xml.backup.orig.txt | sed -e 's#RisingOS-Revived/official_devices/.*VANILLA.*json#Joe7500/Builds/main/rising-8-rev-vanilla-chime.json#g' > strings.xml.new.txt
mv strings.xml.new.txt strings.xml.backup.orig.txt
cat strings.xml.backup.orig.txt | sed -e 's#RisingOS-Revived/official_devices/.*CORE.*json#Joe7500/Builds/main/rising-8-rev-core-chime.json#g' > strings.xml.new.txt
mv strings.xml.new.txt strings.xml.backup.orig.txt
cp strings.xml.backup.orig.txt strings.xml
cp -f strings.xml packages/apps/Updater/app/src/main/res/values/strings.xml

sed -i -e 's#ifeq ($(call is-version-lower-or-equal,$(TARGET_KERNEL_VERSION),6.1),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/lineage/build/tasks/kernel.mk
sed -i -e 's#ifeq ($(call is-version-greater-or-equal,$(TARGET_KERNEL_VERSION),5.15),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/lineage/build/tasks/kernel.mk
sed -i -e 's#GKI_SUFFIX := /$(shell echo android$(PLATFORM_VERSION)-$(TARGET_KERNEL_VERSION))#NOT_NEEDED_DISCARD_567 := true#g' vendor/lineage/build/tasks/kernel.mk

#cd frameworks/base
#echo 'diff --git a/core/java/android/view/animation/AnimationUtils.java b/core/java/android/view/animation/AnimationUtils.java
#index 4f12750fa..9ad79bd5f 100644
#--- a/core/java/android/view/animation/AnimationUtils.java
#+++ b/core/java/android/view/animation/AnimationUtils.java
#@@ -240,7 +240,7 @@ public class AnimationUtils {
#             throws NotFoundException {
#         int animStyle = Settings.System.getInt(
#                 context.getContentResolver(),
#-                "system_animation_style", 0);
#+                "system_animation_style", 3);
#         if (animStyle != lastAnimStyle) {
#             clearCachedAnimations();
#             lastAnimStyle = animStyle;' > 1.patch
#patch -f -p 1 < 1.patch
#cd -

#cd packages/apps/Personalization
#echo 'diff --git a/res/xml/rising_settings_themes.xml b/res/xml/rising_settings_themes.xml
#index 73cbffb..7ce0d40 100644
#--- a/res/xml/rising_settings_themes.xml
#+++ b/res/xml/rising_settings_themes.xml
#@@ -143,7 +143,7 @@
#             android:dialogTitle="@string/system_animation_style_title"
#             android:entries="@array/system_animation_styles_entries"
#             android:entryValues="@array/system_animation_styles_values"
#-            android:defaultValue="0"
#+            android:defaultValue="3"
#             android:su' > 1.patch
#patch -f -p 1 < 1.patch
#cd -

# Setup device tree
cd device/xiaomi/chime
git revert --no-edit ea4aba08985fe0addebcaed19a86e86bad64239c #squiggly

export RISING_MAINTAINER="Joe"
cat lineage_chime.mk | grep -v "RESERVE_SPACE_FOR_GAPPS" > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
cat lineage_chime.mk | grep -v "WITH_GMS" > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk

echo 'RISING_MAINTAINER="Joe"' >> lineage_chime.mk
echo 'RISING_MAINTAINER := Joe'  >> lineage_chime.mk
echo 'PRODUCT_BUILD_PROP_OVERRIDES += \
    RisingChipset="Chime" \
    RisingMaintainer="Joe"' >> lineage_chime.mk

# GAPPS
if echo $@ | grep GAPPS ; then
   echo "RESERVE_SPACE_FOR_GAPPS := false" >> lineage_chime.mk
   echo 'WITH_GMS := true' >> lineage_chime.mk
#   echo 'TARGET_DEFAULT_PIXEL_LAUNCHER := false' >> lineage_chime.mk
#   echo 'TARGET_PREBUILT_LAWNCHAIR_LAUNCHER := false' >> lineage_chime.mk
   echo 'TARGET_DEFAULT_PIXEL_LAUNCHER := false' >> lineage_chime.mk
   echo 'PRODUCT_SYSTEM_PROPERTIES += persist.sys.default_launcher=0' >> lineage_chime.mk
   echo 'PRODUCT_SYSTEM_PROPERTIES += persist.sys.quickswitch_pixel_shipped=1' >> lineage_chime.mk
   cd -
else
# VANILLA
   echo "RESERVE_SPACE_FOR_GAPPS := true" >> lineage_chime.mk
   echo 'WITH_GMS := false' >> lineage_chime.mk
#   echo 'TARGET_DEFAULT_PIXEL_LAUNCHER := false' >> lineage_chime.mk
#   echo 'TARGET_PREBUILT_LAWNCHAIR_LAUNCHER := false' >> lineage_chime.mk
   echo 'TARGET_PREBUILT_LAWNCHAIR_LAUNCHER := true' >> lineage_chime.m
   echo 'PRODUCT_PACKAGES += Gallery2' >> device.mk
fi

cd ../../../

cat device/xiaomi/chime/configs/vintf/manifest.xml | grep -v '</manifest>' > device/xiaomi/chime/configs/vintf/manifest.xml.1
mv device/xiaomi/chime/configs/vintf/manifest.xml.1 device/xiaomi/chime/configs/vintf/manifest.xml
echo '   <hal format="hidl">
        <name>vendor.qti.hardware.servicetracker</name>
        <transport>hwbinder</transport>
        <version>1.2</version>
        <interface>
            <name>IServicetracker</name>
            <instance>default</instance>
        </interface>
        <fqname>@1.2::IServicetracker/default</fqname>
   </hal>
</manifest>' >> device/xiaomi/chime/configs/vintf/manifest.xml

#echo 'persist.sys.activity_anim_perf_override=true' >> device/xiaomi/chime/configs/props/system.prop
echo 'PERF_ANIM_OVERRIDE := true' >> device/xiaomi/chime/device.mk

cat device/xiaomi/chime/BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > device/xiaomi/chime/BoardConfig.mk.1
mv device/xiaomi/chime/BoardConfig.mk.1 device/xiaomi/chime/BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> device/xiaomi/chime/BoardConfig.mk
echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> device/xiaomi/chime/BoardConfig.mk
echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/device.mk
echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/BoardConfig.mk

# Get and decrypt signing keys
curl -o keys.1  -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/keys/BinlFm0d0LoeeibAVCofXsbYTCtcRHpo
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > keys.tar
tar xf keys.tar
rm -f keys.1 keys.2 keys.tar

# Build it
set +v

source build/envsetup.sh
source build/make/envsetup.sh
source build/envsetup.sh
source build/make/envsetup.sh
export BUILD_USERNAME=user
export BUILD_HOSTNAME=localhost
export KBUILD_BUILD_USER=user
export KBUILD_BUILD_HOST=localhost
riseup chime user                 ; check_fail
mka installclean
rise b                           ; check_fail

set -v

echo success > result.txt
notify_send "Build $PACKAGE_NAME on crave.io succeeded."

# Upload output to pixeldrain
cp out/target/product/chime/$PACKAGE_NAME*.zip .
GO_FILE=`ls --color=never -1tr $PACKAGE_NAME*.zip | tail -1`
GO_FILE_MD5=`md5sum "$GO_FILE"`
GO_FILE=`pwd`/$GO_FILE
if [[ ! -f $GO_FILE ]]; then
   GO_FILE=builder.sh
fi
curl -T "$GO_FILE" -u :$PDAPIKEY https://pixeldrain.com/api/file/ > out.json
PD_ID=`cat out.json | cut -d '"' -f 4`
notify_send "MD5:$GO_FILE_MD5 https://pixeldrain.com/u/$PD_ID"
rm -f out.json

# Upload file to SF
curl -o keys.1  -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/keys/usfJoFvObArLx0KmBzwerPPTzliixTN2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > sf
chmod a-x sf
chmod go-rwx sf
rsync -avP -e 'ssh -i ./sf -o "StrictHostKeyChecking accept-new"' $GO_FILE $SF_URL
rm -f keys.1 keys.2 sf

# Generate and send OTA json file
curl -o genota.sh -L https://raw.githubusercontent.com/Joe7500/Builds/refs/heads/main/genota.sh
bash genota.sh "$GENOTA_ARG_1" "$GENOTA_ARG_2" "$GO_FILE"
curl -L -F document=@"$GO_FILE.json.txt" -F caption="OTA $GO_FILE.json.txt" -F chat_id="$TG_CID" -X POST https://api.telegram.org/bot$TG_TOKEN/sendDocument > /dev/null 2>&1
rm -f genota.sh

TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
notify_send "Build $PACKAGE_NAME on crave.io completed. $TIME_TAKEN."

cleanup_self
exit 0
