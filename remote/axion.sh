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
DEVICE_BRANCH=lineage-23.1
VENDOR_BRANCH=lineage-23.1
XIAOMI_BRANCH=lineage-23.1
REPO_URL="-u https://github.com/AxionAOSP/android.git -b lineage-23.1 --git-lfs"
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
   rm -rf vendor/lineage-priv/keys vendor/lineage-priv priv-keys .config/b2/ /home/admin/.config/b2/
   cd packages/apps/Updater/ && git reset --hard && cd ../../../
   cd packages/modules/Connectivity/ && git reset --hard && cd ../../../
   rm -rf prebuilts/clang/kernel/linux-x86/clang-stablekern/ prebuilts/clang/host/linux-x86/clang-stablekern/
   rm -rf hardware/xiaomi/ device/xiaomi/chime/ vendor/xiaomi/chime/ kernel/xiaomi/chime/
   rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml* builder.sh goupload.sh GOFILE.txt
   rm -rf /tmp/android-certs* /home/admin/venv/
   rm -rf custom_scripts/
   cd /home/admin
   rm -rf .tdl
   rm -rf  LICENSE  README.md  README_zh.md  tdl  tdl_key tdl_Linux_64bit.tar.gz* venv tdl.zip tdl_Linux.tgz tdl.sh
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
cat strings.xml | sed -e "s#$OTA_SED_STRING#Joe7500/Builds/main/$PACKAGE_NAME.VANILLA.chime.json#g" > strings.xml.1
cp strings.xml.1 packages/apps/Updater/app/src/main/res/values/strings.xml
check_fail

sed -i -e 's#ifeq ($(call is-version-lower-or-equal,$(TARGET_KERNEL_VERSION),6.1),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/lineage/build/tasks/kernel.mk
sed -i -e 's#ifeq ($(call is-version-greater-or-equal,$(TARGET_KERNEL_VERSION),5.15),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/lineage/build/tasks/kernel.mk
sed -i -e 's#GKI_SUFFIX := /$(shell echo android$(PLATFORM_VERSION)-$(TARGET_KERNEL_VERSION))#NOT_NEEDED_DISCARD_567 := true#g' vendor/lineage/build/tasks/kernel.mk

cat vendor/lineage/prebuilt/common/bin/backuptool.sh | sed -e 's/export V=23/export V=2/g' > vendor/lineage/prebuilt/common/bin/backuptool.sh.1
mv vendor/lineage/prebuilt/common/bin/backuptool.sh.1 vendor/lineage/prebuilt/common/bin/backuptool.sh

# Setup device tree
cd device/xiaomi/chime && git reset --hard ; check_fail
git revert --no-edit ea4aba08985fe0addebcaed19a86e86bad64239c #squiggly

echo 'AXION_MAINTAINER := Joe' >> lineage_chime.mk
echo 'AXION_PROCESSOR := Snapdragon_662' >> lineage_chime.mk
echo 'AXION_CPU_SMALL_CORES := 0,1,2,3' >> lineage_chime.mk
echo 'AXION_CPU_BIG_CORES := 4,5,6,7' >> lineage_chime.mk
echo 'AXION_CAMERA_REAR_INFO := 48' >> lineage_chime.mk
echo 'AXION_CAMERA_FRONT_INFO := 8' >> lineage_chime.mk
echo 'GPU_FREQS_PATH := /sys/class/devfreq/5900000.qcom,kgsl-3d0/available_frequencies' >> lineage_chime.mk
echo 'GPU_MIN_FREQ_PATH := /sys/class/devfreq/5900000.qcom,kgsl-3d0/min_freq' >> lineage_chime.mk
echo 'PERF_ANIM_OVERRIDE := true' >> lineage_chime.mk

echo 'genfscon proc /sys/vm/dirty_writeback_centisecs     u:object_r:proc_dirty:s0' >> sepolicy/vendor/genfs_contexts
echo 'genfscon proc /sys/vm/vfs_cache_pressure            u:object_r:proc_drop_caches:s0' >> sepolicy/vendor/genfs_contexts
echo 'genfscon proc /sys/vm/dirty_ratio u:object_r:proc_dirty:s0' >> sepolicy/vendor/genfs_contexts
echo 'genfscon proc /sys/kernel/sched_migration_cost_ns u:object_r:proc_sched:s0' >> sepolicy/vendor/genfs_contexts
echo 'allow init vendor_sysfs_kgsl:file setattr;' >> sepolicy/vendor/init.te
#echo 'genfscon sysfs /devices/platform/1c500000.mali/available_frequencies u:object_r:sysfs_gpu:s0' >> sepolicy/vendor/genfs_contexts
#echo 'genfscon sysfs /devices/platform/1c500000.mali/hint_min_freq u:object_r:sysfs_gpu:s0' >> sepolicy/vendor/genfs_contexts
#echo 'allow init proc_vm_dirty:file rw_file_perms;' > sepolicy/vendor/axion.te
#echo 'allow init proc_dirty_ratio:file rw_file_perms;' >>  sepolicy/vendor/axion.te

cat BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> BoardConfig.mk
cat lineage_chime.mk | grep -v TARGET_ENABLE_BLUR > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
echo 'TARGET_ENABLE_BLUR := true' >> lineage_chime.mk
cd ../../../

echo 'TARGET_INCLUDES_LOS_PREBUILTS := true' >> device/xiaomi/chime/lineage_chime.mk

echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> device/xiaomi/chime/BoardConfig.mk

echo 'persist.sys.perf.scroll_opt=true'  >> device/xiaomi/chime/configs/props/system.prop
echo 'persist.sys.perf.scroll_opt.heavy_app=2'  >> device/xiaomi/chime/configs/props/system.prop

echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/device.mk
echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/BoardConfig.mk

#curl -o audio_effects.xml -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/audio_effects_viper.xml
#mv audio_effects.xml device/xiaomi/chime/audio/audio_effects.xml
echo '$(call inherit-product, packages/apps/ViPER4AndroidFX/config.mk)' >> device/xiaomi/chime/device.mk
if ! ls packages/apps/ViPER4AndroidFX/config.mk ; then
   git clone https://github.com/AxionAOSP/android_packages_apps_ViPER4AndroidFX packages/apps/ViPER4AndroidFX
   check_fail
fi

grep activity_anim_perf_override frameworks/base/core/java/android/view/animation/AnimationUtils.java
if [ $? -ne 0 ] ; then
   cd frameworks/base/
   curl -o 1.patch -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/AnimationUtils.java.patch
   patch -p 1 -f < 1.patch ; check_fail
   cd ../../
fi

# Get and decrypt signing keys
curl -o keys.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/BinlFm0d0LoeeibAVCofXsbYTCtcRHpo
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > keys.tar
tar xf keys.tar
rm -f keys.1 keys.2 keys.tar
curl -o tdl.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/ktdlxIevOo3wGJWrun01W1BzVWvKKZGw
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
# Get and decrypt signing keys
curl -o keys.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/BinlFm0d0LoeeibAVCofXsbYTCtcRHpo
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > keys.tar
tar xf keys.tar
rm -f keys.1 keys.2 keys.tar
curl -o tdl.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/ktdlxIevOo3wGJWrun01W1BzVWvKKZGw
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d tdl.1 > tdl.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d tdl.2 > tdl.tar
axion chime user vanilla               ; check_fail
mka installclean
ax -b user                             ; check_fail

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
bash genota.sh axion 2 "$GO_FILE"
curl -L -F document=@"$GO_FILE.json.txt" -F caption="OTA $GO_FILE.json.txt" -F chat_id="$TG_CID" -X POST https://api.telegram.org/bot$TG_TOKEN/sendDocument > /dev/null 2>&1
rm -f genota.sh

TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
notify_send "Build $PACKAGE_NAME on crave.io completed. $TIME_TAKEN."

if [ "$BUILD_TYPE" == "vanilla" ]; then
   cleanup_self
   exit 0
fi

cleanup_self
exit 0
