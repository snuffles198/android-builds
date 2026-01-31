#!/bin/bash

source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc

cd /tmp/src/android/

set -v

# Template helper variables
PACKAGE_NAME=Project_Infinity-X-3
VARIANT_NAME=user
BUILD_TYPE=vanilla
DEVICE_BRANCH=lineage-23.2
VENDOR_BRANCH=lineage-23.2
XIAOMI_BRANCH=lineage-23.2
GENOTA_ARG_1="infinity"
GENOTA_ARG_2="3"
REPO_PARAMS=" --git-lfs --depth=1 --no-tags --no-clone-bundle --no-repo-verify -g default,-mips,-darwin,-notdefault"
REPO_URL=" -u https://github.com/ProjectInfinity-X/manifest -b 16 $REPO_PARAMS"
OTA_SED_STRING="ProjectInfinity-X/official_devices/.*json"
OTA_SED_REPLACE_STRING="Joe7500/Builds/main/$PACKAGE_NAME.$VARIANT_NAME.$BUILD_TYPE.chime.json"
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
curl -o kernel.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/kernel-prebuilt-perf-valeryn-A16.tar.xz" ; check_fail
tar xf kernel.tar.xz ; check_fail
rm -f kernel.tar.xz
curl -o lineage-22.1.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/lineage-22.1.tar.xz" ; check_fail
tar xf lineage-22.1.tar.xz ; check_fail
rm -f lineage-22.1.tar.xz
curl -o toolchain.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/toolchain.tar.xz" ; check_fail
tar xf toolchain.tar.xz ; check_fail
rm -f toolchain.tar.xz
git clone https://github.com/snuffles198/device_tree -b $DEVICE_BRANCH device/xiaomi/chime ; check_fail
git clone https://github.com/snuffles198/vendor_tree -b $VENDOR_BRANCH vendor/xiaomi/chime ; check_fail
git clone https://github.com/LineageOS/android_hardware_xiaomi -b $XIAOMI_BRANCH hardware/xiaomi ; check_fail

# Setup AOSP source 
patch -f -p 1 < wfdservice.rc.patch ; check_fail
cd packages/modules/Connectivity/ && git reset --hard && cd ../../../
patch -f -p 1 < InterfaceController.java.patch ; check_fail
rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml.*
rm -f vendor/xiaomi/chime/proprietary/system_ext/etc/init/wfdservice.rc.rej
rm -f packages/modules/Connectivity/staticlibs/device/com/android/net/module/util/ip/InterfaceController.java.rej

cd packages/apps/Updater/ && git reset --hard && cd ../../../
cp packages/apps/Updater/app/src/main/res/values/strings.xml strings.xml
cat strings.xml | sed -e "s#$OTA_SED_STRING#Joe7500/Builds/main/$PACKAGE_NAME.$VARIANT_NAME.chime.json#g" > strings.xml.1
mv strings.xml.1 strings.xml
cat strings.xml | sed -e "s#ProjectInfinity-X/official_devices/master/changelog/.*txt#Joe7500/Builds/main/infx-16.txt#g" > strings.xml.1
cp strings.xml.1 packages/apps/Updater/app/src/main/res/values/strings.xml
check_fail
sed -i "s#$OTA_SED_STRING#Joe7500/Builds/main/$PACKAGE_NAME.$VARIANT_NAME.gapps.json#g" vendor/infinity/overlay/updater/res/values/strings.xml
cd vendor/infinity/ && git add . && git commit -m update ; cd -
#(sleep 600 ; sed -i -e "s#$OTA_SED_STRING#Joe7500/Builds/main/$PACKAGE_NAME.$VARIANT_NAME.gapps.json#g" vendor/infinity/overlay/updater/res/values/strings.xml)&

for i in `grep -R '<string name="unofficial_build_suffix">' packages/apps/Settings/res | cut -d ':' -f 1` ; do
  cat $i | sed -e 's#<string name="unofficial_build_suffix">.*string>#<string name="unofficial_build_suffix">- Community</string>#g' > $i.1
  mv $i.1 $i
done
cd vendor/infinity/
cat config/version.mk | sed -e 's/INFINITY_BUILD_TYPE ?= UNOFFICIAL/INFINITY_BUILD_TYPE := COMMUNITY/g' > config/version.mk.1
mv config/version.mk.1 config/version.mk
cd ../..

sed -i -e 's#ifeq ($(call is-version-lower-or-equal,$(TARGET_KERNEL_VERSION),6.1),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/infinity/build/tasks/kernel.mk
sed -i -e 's#ifeq ($(call is-version-greater-or-equal,$(TARGET_KERNEL_VERSION),5.15),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/infinity/build/tasks/kernel.mk
sed -i -e 's#GKI_SUFFIX := /$(shell echo android$(PLATFORM_VERSION)-$(TARGET_KERNEL_VERSION))#NOT_NEEDED_DISCARD_567 := true#g' vendor/infinity/build/tasks/kernel.mk

#grep activity_anim_perf_override frameworks/base/core/java/android/view/animation/AnimationUtils.java
#if [ $? -ne 0 ] ; then
#   cd frameworks/base/
#   curl -o 1.patch -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/AnimationUtils.java.patch
#   patch -p 1 -f < 1.patch ; check_fail
#   cd ../../
#fi

cat vendor/infinity/prebuilt/common/bin/backuptool.sh | sed -e 's/ro.infinity.aversion/ro.infinity.a\.\*version/g' > vendor/infinity/prebuilt/common/bin/backuptool.sh.1
mv vendor/infinity/prebuilt/common/bin/backuptool.sh.1 vendor/infinity/prebuilt/common/bin/backuptool.sh

# Setup device tree

cd device/xiaomi/chime
#git revert --no-edit ea4aba08985fe0addebcaed19a86e86bad64239c #squiggly
cat AndroidProducts.mk | sed -e s/lineage/infinity/g > AndroidProducts.mk.1
mv AndroidProducts.mk.1 AndroidProducts.mk
cat lineage_chime.mk | sed -e s/lineage/infinity/g > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
mv lineage_chime.mk infinity_chime.mk
echo 'INFINITY_MAINTAINER := "Joe"' >> infinity_chime.mk
#cat BoardConfig.mk | sed -e s#vendor/lineage/config/device_framework_matrix.xml#vendor/infinity/config/device_framework_matrix.xml#g > BoardConfig.mk.1
cat BoardConfig.mk | grep -v 'vendor/lineage/config/device_framework_matrix.xml' > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk
echo 'ro.product.marketname=POCO M3 / Redmi 9T' >> configs/props/system.prop
echo 'ro.infinity.soc=Qualcomm SM6115 Snapdragon 662' >> configs/props/system.prop
echo 'ro.infinity.battery=6000 mAh' >> configs/props/system.prop
echo 'ro.infinity.display=1080 x 2340' >> configs/props/system.prop
echo 'ro.infinity.camera=48MP + 8MP' >> configs/props/system.prop
echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> BoardConfig.mk
echo 'ro.launcher.blur.appLaunch=0' >> configs/props/product.prop
echo 'ro.surface_flinger.supports_background_blur=1' >> configs/props/product.prop
echo 'persist.sys.sf.disable_blurs=1' >> configs/props/product.prop
echo 'ro.sf.blurs_are_expensive=1' >> configs/props/product.prop
cd -

cat device/xiaomi/chime/infinity_chime.mk | grep -v RESERVE_SPACE_FOR_GAPPS > device/xiaomi/chime/infinity_chime.mk.1
mv device/xiaomi/chime/infinity_chime.mk.1 device/xiaomi/chime/infinity_chime.mk
cat device/xiaomi/chime/infinity_chime.mk | grep -v WITH_GAPPS > device/xiaomi/chime/infinity_chime.mk.1
mv device/xiaomi/chime/infinity_chime.mk.1 device/xiaomi/chime/infinity_chime.mk

# GAPPS
if echo $@ | grep GAPPS ; then
   echo 'WITH_GAPPS := true' >> device/xiaomi/chime/infinity_chime.mk
   echo 'RESERVE_SPACE_FOR_GAPPS := false' >> device/xiaomi/chime/infinity_chime.mk
else
# VANILLA
   echo 'WITH_GAPPS := false' >> device/xiaomi/chime/infinity_chime.mk
   echo 'RESERVE_SPACE_FOR_GAPPS := true' >> device/xiaomi/chime/infinity_chime.mk
fi

cat device/xiaomi/chime/BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > device/xiaomi/chime/BoardConfig.mk.1
mv device/xiaomi/chime/BoardConfig.mk.1 device/xiaomi/chime/BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> device/xiaomi/chime/BoardConfig.mk
echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> device/xiaomi/chime/BoardConfig.mk

echo 'persist.sys.activity_anim_perf_override=true' >> device/xiaomi/chime/configs/props/product.prop
echo 'PERF_ANIM_OVERRIDE := true' >> device/xiaomi/chime/device.mk
echo 'PERF_ANIM_OVERRIDE := true' >> device/xiaomi/chime/BoardConfig.mk

#curl -o audio_effects.xml -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/audio_effects_viper.xml
#mv audio_effects.xml device/xiaomi/chime/audio/audio_effects.xml
#echo '$(call inherit-product, packages/apps/ViPER4AndroidFX/config.mk)' >> device/xiaomi/chime/device.mk
#if ! ls packages/apps/ViPER4AndroidFX/config.mk ; then
#   git clone https://github.com/AxionAOSP/android_packages_apps_ViPER4AndroidFX packages/apps/ViPER4AndroidFX
#   check_fail
#fi

echo 'PRODUCT_PACKAGES += Updater' >> device/xiaomi/chime/device.mk
echo 'PRODUCT_PACKAGES += UpdaterGMSOverlay' >> device/xiaomi/chime/device.mk

echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/device.mk
echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/BoardConfig.mk

echo 'PRODUCT_ENABLE_UFFD_GC := true' >> device/xiaomi/chime/device.mk

# Get and decrypt signing keys
curl -o keys.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/BinlFm0d0LoeeibAVCofXsbYTCtcRHpo
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > keys.tar
tar xf keys.tar
rm -f keys.1 keys.2 keys.tar

# Build it
set +v

source build/envsetup.sh          ; check_fail
source build/envsetup.sh
export BUILD_USERNAME=user
export BUILD_HOSTNAME=localhost
export KBUILD_BUILD_USER=user
export KBUILD_BUILD_HOST=localhost
lunch infinity_chime-user         ; check_fail
mka installclean
mka bacon                         ; check_fail

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
curl -o keys.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/usfJoFvObArLx0KmBzwerPPTzliixTN2
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



CONTINUE=0
echo "$@" | grep CONTINUE
if [ $? -eq 0 ]; then CONTINUE=1 ; fi
if [ $CONTINUE -eq 1 ] ; then

cat device/xiaomi/chime/infinity_chime.mk | grep -v RESERVE_SPACE_FOR_GAPPS > device/xiaomi/chime/infinity_chime.mk.1
mv device/xiaomi/chime/infinity_chime.mk.1 device/xiaomi/chime/infinity_chime.mk
cat device/xiaomi/chime/infinity_chime.mk | grep -v WITH_GAPPS > device/xiaomi/chime/infinity_chime.mk.1
mv device/xiaomi/chime/infinity_chime.mk.1 device/xiaomi/chime/infinity_chime.mk

# GAPPS
   echo 'WITH_GAPPS := true' >> device/xiaomi/chime/infinity_chime.mk
   echo 'RESERVE_SPACE_FOR_GAPPS := false' >> device/xiaomi/chime/infinity_chime.mk

# Build it
set +v

source build/envsetup.sh          ; check_fail
source build/envsetup.sh
export BUILD_USERNAME=user
export BUILD_HOSTNAME=localhost
export KBUILD_BUILD_USER=user
export KBUILD_BUILD_HOST=localhost
lunch infinity_chime-user         ; check_fail
mka installclean
mka bacon                         ; check_fail

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
curl -o keys.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/usfJoFvObArLx0KmBzwerPPTzliixTN2
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

fi





cleanup_self
exit 0


