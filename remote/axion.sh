#!/bin/bash

source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc

cd /tmp/src/android/

set -v

# Template helper variables
PACKAGE_NAME=axion
VARIANT_NAME=user
BUILD_TYPE=vanilla
DEVICE_BRANCH=lineage-23.0
VENDOR_BRANCH=lineage-23.0
XIAOMI_BRANCH=lineage-23.0
REPO_URL="-u https://github.com/AxionAOSP/android.git -b lineage-23.0 --git-lfs"
OTA_SED_STRING="AxionAOSP/official_devices/.*json"

# Random template helper stuff
export BUILD_USERNAME=user
export BUILD_HOSTNAME=localhost 
export KBUILD_BUILD_USER=user
export KBUILD_BUILD_HOST=localhost
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
   rm -rf vendor/lineage-priv/keys
   rm -rf vendor/lineage-priv
   rm -rf priv-keys
   rm -rf .config/b2/
   rm -rf /home/admin/.config/b2/
   cd packages/apps/Updater/ && git reset --hard && cd ../../../
   cd packages/modules/Connectivity/ && git reset --hard && cd ../../../
   rm -rf prebuilts/clang/kernel/linux-x86/clang-stablekern/
   rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
   rm -rf hardware/xiaomi/
   rm -rf device/xiaomi/chime/
   rm -rf vendor/xiaomi/chime/
   rm -rf kernel/xiaomi/chime/
   rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml* builder.sh goupload.sh GOFILE.txt
   rm -rf /tmp/android-certs*
   rm -rf /home/admin/venv/
   rm -rf custom_scripts/
   cd /home/admin
   rm -rf .tdl
   rm -rf  LICENSE  README.md  README_zh.md  tdl  tdl_key  tdl_Linux_64bit.tar.gz* venv tdl.zip tdl_Linux.tgz
   rm -f tdl.sh
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
   repo init $REPO_URL  ; check_fail
   cleanup_self
   /opt/crave/resync.sh ; check_fail
fi

# Download trees
rm -rf kernel/xiaomi/chime/
rm -rf vendor/xiaomi/chime/
rm -rf device/xiaomi/chime/
rm -rf hardware/xiaomi/
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
cp packages/apps/Updater/app/src/main/res/values/strings.xml strings.xml
cat strings.xml | sed -e "s#$OTA_SED_STRING#Joe7500/Builds/main/$PACKAGE_NAME.VANILLA.chime.json#g" > strings.xml.1
cp strings.xml.1 packages/apps/Updater/app/src/main/res/values/strings.xml
check_fail

sed -i -e 's#ifeq ($(call is-version-lower-or-equal,$(TARGET_KERNEL_VERSION),6.1),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/lineage/build/tasks/kernel.mk
sed -i -e 's#ifeq ($(call is-version-greater-or-equal,$(TARGET_KERNEL_VERSION),5.15),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/lineage/build/tasks/kernel.mk
sed -i -e 's#GKI_SUFFIX := /$(shell echo android$(PLATFORM_VERSION)-$(TARGET_KERNEL_VERSION))#NOT_NEEDED_DISCARD_567 := true#g' vendor/lineage/build/tasks/kernel.mk

#cd vendor/lineage && git reset --hard && cd ../..
#cp vendor/lineage/prebuilt/common/bin/backuptool.sh backuptool.sh
#cat backuptool.sh | sed -e 's#export V=22#export V=2# g' > backuptool.sh.1
#cp backuptool.sh.1 vendor/lineage/prebuilt/common/bin/backuptool.sh
#rm backuptool.sh

# Setup device tree
cd device/xiaomi/chime && git reset --hard ; check_fail
git revert --no-edit ea4aba08985fe0addebcaed19a86e86bad64239c #squiggly
echo 'AXION_MAINTAINER := Joe' >> lineage_chime.mk
echo 'AXION_PROCESSOR := Snapdragon_662' >> lineage_chime.mk
echo 'AXION_CPU_SMALL_CORES := 0,1,2,3' >> lineage_chime.mk
echo 'AXION_CPU_BIG_CORES := 4,5,6,7' >> lineage_chime.mk
echo 'AXION_CAMERA_REAR_INFO := 48' >> lineage_chime.mk
echo 'AXION_CAMERA_FRONT_INFO := 8' >> lineage_chime.mk
echo 'GPU_FREQS_PATH := /sys/devices/platform/soc/5900000.qcom,kgsl-3d0/devfreq/5900000.qcom,kgsl-3d0/available_frequencies' >> lineage_chime.mk
echo 'GPU_MIN_FREQ_PATH := /sys/devices/platform/soc/5900000.qcom,kgsl-3d0/devfreq/5900000.qcom,kgsl-3d0/min_freq' >> lineage_chime.mk
echo 'PERF_ANIM_OVERRIDE := true' >> lineage_chime.mk
echo 'genfscon proc /sys/vm/dirty_writeback_centisecs     u:object_r:proc_dirty:s0' >> sepolicy/vendor/genfs_contexts
echo 'genfscon proc /sys/vm/vfs_cache_pressure            u:object_r:proc_drop_caches:s0' >> sepolicy/vendor/genfs_contexts
echo 'genfscon proc /sys/vm/dirty_ratio u:object_r:proc_dirty:s0' >> sepolicy/vendor/genfs_contexts
echo 'genfscon proc /sys/kernel/sched_migration_cost_ns u:object_r:proc_sched:s0' >> sepolicy/vendor/genfs_contexts
cat BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> BoardConfig.mk
cat lineage_chime.mk | grep -v TARGET_ENABLE_BLUR > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
echo 'TARGET_ENABLE_BLUR := true' >> lineage_chime.mk
echo 'ro.launcher.blur.appLaunch=0' >> configs/props/system.prop
#echo 'ro.surface_flinger.supports_background_blur=1' >> configs/props/system.prop
#echo 'persist.sys.sf.disable_blurs=1' >> configs/props/system.prop
echo 'ro.sf.blurs_are_expensive=1' >> configs/props/system.prop
cd ../../../

#echo 'CONFIG_SCHED_DEBUG=n' >> kernel/xiaomi/chime/arch/arm64/configs/vendor/chime_defconfig

echo 'TARGET_INCLUDES_LOS_PREBUILTS := true' >> device/xiaomi/chime/lineage_chime.mk

echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> device/xiaomi/chime/BoardConfig.mk

echo 'persist.sys.perf.scroll_opt=true'  >> device/xiaomi/chime/configs/props/system.prop
echo 'persist.sys.perf.scroll_opt.heavy_app=2'  >> device/xiaomi/chime/configs/props/system.prop

echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/device.mk
echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/BoardConfig.mk

cd vendor/xiaomi/chime
curl -o rising.tar.xz -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/src/rising-vendor.tar.xz
tar xf rising.tar.xz ; check_fail
rm rising.tar.xz
cd -

# Setup kernel
#cd kernel/xiaomi/chime
#patch -f -p 1 -R  < sched_param_perf.patch
#cd ../../../

# Get and decrypt signing keys
curl -o keys.1  -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/keys/BinlFm0d0LoeeibAVCofXsbYTCtcRHpo
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > keys.tar
tar xf keys.tar
rm -f keys.1 keys.2 keys.tar
curl -o tdl.1  -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/keys/ktdlxIevOo3wGJWrun01W1BzVWvKKZGw
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d tdl.1 > tdl.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d tdl.2 > tdl.tar
tar xf tdl.tar
rm -f tdl.1 tdl.2 tdl.tar
mv tdl.zip /home/admin/

sleep 10

# Build it
set +v

# axion Usage: axion <device_codename> [user|userdebug|eng] [gms [pico|core] | vanilla]
# ax usage: ax [-b|-fb|-br] [-j<num>] [user|eng|userdebug]
# Build Types: -b Bacon -fb Fastboot -br Brunch
source build/envsetup.sh               ; check_fail
source build/envsetup.sh 
source build/envsetup.sh 
axion chime user vanilla               ; check_fail
mka installclean
ax -b user                             ; check_fail

set -v

echo success > result.txt
notify_send "Build $PACKAGE_NAME on crave.io succeeded."

# Upload output to gofile
cp out/target/product/chime/$PACKAGE_NAME*.zip .
GO_FILE=`ls --color=never -1tr $PACKAGE_NAME*.zip | tail -1`
GO_FILE_MD5=`md5sum "$GO_FILE"`
GO_FILE=`pwd`/$GO_FILE
curl -o goupload.sh -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/utils/gofile.sh
bash goupload.sh $GO_FILE
GO_LINK=`cat GOFILE.txt`
notify_send "MD5:$GO_FILE_MD5 $GO_LINK"
rm -f goupload.sh GOFILE.txt

# Upload output to telegram
if [[ ! -f $GO_FILE ]]; then
   GO_FILE=builder.sh
fi
cd /home/admin
VERSION=$(curl --silent "https://api.github.com/repos/iyear/tdl/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
wget -O tdl_Linux.tgz https://github.com/iyear/tdl/releases/download/$VERSION/tdl_Linux_64bit.tar.gz ; check_fail
tar xf tdl_Linux.tgz ; check_fail
unzip -o -P $TDL_ZIP_PASSWD tdl.zip ; check_fail
cd /tmp/src/android/
/home/admin/tdl upload -c $TDL_CHAT_ID -p "$GO_FILE"
cd /home/admin
rm -rf .tdl
rm -rf  LICENSE  README.md  README_zh.md  tdl  tdl_key  tdl_Linux_64bit.tar.gz* venv
rm -f tdl.sh
cd /tmp/src/android/

# Generate and send OTA json file
curl -o genota.sh -L https://raw.githubusercontent.com/Joe7500/Builds/refs/heads/main/genota.sh
bash genota.sh axion 1 "$GO_FILE"
curl -L -F document=@"$GO_FILE.json.txt" -F caption="OTA $GO_FILE.json.txt" -F chat_id="$TG_CID" -X POST https://api.telegram.org/bot$TG_TOKEN/sendDocument > /dev/null 2>&1
rm -f genota.sh

TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
notify_send "Build $PACKAGE_NAME on crave.io completed. $TIME_TAKEN."

if [ "$BUILD_TYPE" == "vanilla" ]; then
   cleanup_self
   exit 0
fi

# Do gapps dirty build
#
#
#

# Setup AOSP source

# Setup device tree

# Build it

# Upload output to gofile

# Upload output to telegram

cleanup_self
exit 0
