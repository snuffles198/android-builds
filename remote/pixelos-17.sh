#!/bin/bash

source ~/android-builds/dev-secrets/telegram.sh
source ~/android-builds/dev-secrets/secrets.sh
source ~/android-builds/dev-secrets/ntfy.sh
source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc

mkdir -p /tmp/src
if [ ! -d /tmp/src/android ] || [ -L /tmp/src/android ]; then
  if [ "$(pwd)" != "/tmp/src/android" ]; then
   rm -rf /tmp/src/android
   ln -s "$PWD" /tmp/src/android
  fi
fi

cd /tmp/src/android/

set -v

# Template helper variables
PACKAGE_NAME=PixelOS
VARIANT_NAME=user
BUILD_TYPE=vanilla
DEVICE_BRANCH=lineage-24.0-BETA
VENDOR_BRANCH=lineage-24.0-BETA
XIAOMI_BRANCH=lineage-23.2
GENOTA_ARG_1="pixelos"
GENOTA_ARG_2="17"
REPO_PARAMS=" --git-lfs --depth=1 --no-tags --no-clone-bundle"
REPO_URL="-u https://github.com/PixelOS-AOSP/android_manifest -b seventeen $REPO_PARAMS"
OTA_SED_STRING="PixelOS-AOSP/official_devices/.*json"
TODAY=`date +"%d%m%y"`
OTA_SED_REPLACE_STRING="Joe7500/Builds/main/$PACKAGE_NAME.16.$VARIANT_NAME.$BUILD_TYPE.chime.json"
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

notify_send "Build $PACKAGE_NAME on crave.io OTA string: $PACKAGE_NAME.16.$VARIANT_NAME.$BUILD_TYPE.chime.json"
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
   tar xf hardware.tar ; tar xf kernel.tar  ; tar xf device.tar
   /opt/crave/resync.sh
   repo forall -c "git clean -fdx ; git reset --hard HEAD"
   /opt/crave/resync.sh ; check_fail
fi
tar cf hardware.tar hardware/ ; tar cf kernel.tar kernel/ ; tar cf device.tar device/

TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
notify_send "Build $PACKAGE_NAME on crave.io repo sync done. $TIME_TAKEN."

# Download trees
rm -rf kernel/xiaomi/chime/ vendor/xiaomi/chime/ device/xiaomi/chime/ hardware/xiaomi/
rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
curl -o kernel.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/kernel-prebuilt-perf-valeryn-A17.tar.xz" ; check_fail
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
cat strings.xml | sed -e "s#$OTA_SED_STRING#$OTA_SED_REPLACE_STRING#g" > strings.xml.1
cp strings.xml.1 packages/apps/Updater/app/src/main/res/values/strings.xml
check_fail

sed -i -e 's#ifeq ($(call is-version-lower-or-equal,$(TARGET_KERNEL_VERSION),6.1),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/lineage/build/tasks/kernel.mk
sed -i -e 's#ifeq ($(call is-version-greater-or-equal,$(TARGET_KERNEL_VERSION),5.15),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/lineage/build/tasks/kernel.mk
sed -i -e 's#GKI_SUFFIX := /$(shell echo android$(PLATFORM_VERSION)-$(TARGET_KERNEL_VERSION))#NOT_NEEDED_DISCARD_567 := true#g' vendor/lineage/build/tasks/kernel.mk

grep activity_anim_perf_override frameworks/base/core/java/android/view/animation/AnimationUtils.java
if [ $? -ne 0 ] ; then
   cd frameworks/base/
   curl -o 1.patch -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/AnimUtils-A17.patch
   patch -p 1 -f < 1.patch ; check_fail
   cd ../../
fi

rm -f hardware/xiaomi/megvii/Android.bp

# Setup device tree
cd device/xiaomi/chime
git revert --no-edit ea4aba08985fe0addebcaed19a86e86bad64239c #squiggly
git revert --no-edit 0a790d4fabf2745212e827d5868f9703b2ec47ed #blur by defaut
curl -o configs/powerhint.json -L "https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/powerhint.json.axion.7.txt" ; check_fail
sed -i -e 's#vendor/lineage/config#vendor/custom/config#g' lineage_chime.mk
sed -i -e 's#lineage#custom#g' AndroidProducts.mk
echo 'ro.launcher.blur.appLaunch=0' >> configs/props/system.prop
echo 'ro.surface_flinger.supports_background_blur=1' >> configs/props/system.prop
echo 'persist.sys.sf.disable_blurs=1' >> configs/props/system.prop
echo 'ro.sf.blurs_are_expensive=1' >> configs/props/system.prop
echo 'TARGET_ENABLE_BLUR := true' >> lineage_chime.mk

echo '<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <privapp-permissions package="net.pixelos.ota">
        <permission name="android.permission.ACCESS_CACHE_FILESYSTEM" />
        <permission name="android.permission.REBOOT" />
        <permission name="android.permission.RECOVERY" />
        <permission name="android.permission.START_ACTIVITIES_FROM_BACKGROUND" />
        <permission name="android.permission.INSTALL_PACKAGES" />
    </privapp-permissions>
</permissions>' > updater.txt
echo 'PRODUCT_COPY_FILES += $(LOCAL_PATH)/updater.txt:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/permissions/privapp_whitelist_net.pixelos.ota.xml' >> device.mk
echo 'PRODUCT_PACKAGES += Updater' >> device.mk

touch dummy
echo 'PRODUCT_COPY_FILES += $(LOCAL_PATH)/dummy:$(TARGET_COPY_OUT_SYSTEM)/addon.d/.placeholder' >> device.mk
echo 'PRODUCT_COPY_FILES += $(LOCAL_PATH)/dummy:$(TARGET_COPY_OUT_SYSTEM)/system/addon.d/.placeholder' >> device.mk

echo 'ro.lmk.kill_heaviest_task=true
ro.lmk.use_psi=true
ro.lmk.use_cgroup_v2=true
ro.lmk.use_minfree_levels=false
ro.lmk.thrashing_limit_decay=50
ro.lmk.downgrade_pressure=30
ro.lmk.psi_partial_stall_ms=200
ro.lmk.psi_complete_stall_ms=700
ro.lmk.thrashing_limit=30
ro.lmk.swap_util_max=100
ro.lmk.swap_free_low_percentage=10' >> configs/props/system.prop

echo '
prebuilt_etc {
    name: "init.custom.rc",
    src: "etc/init.custom.rc",
    sub_dir: "init",
    filename: "init.custom.rc",
}' >> rootdir/Android.bp

echo 'on property:sys.boot_completed=1
    exec -- /system/bin/sleep 10
    write /proc/sys/vm/swappiness 100' > rootdir/etc/init.custom.rc

echo 'PRODUCT_PACKAGES += init.custom.rc' >> device.mk

cd ../../../

cat device/xiaomi/chime/lineage_chime.mk | grep -v RESERVE_SPACE_FOR_GAPPS > device/xiaomi/chime/lineage_chime.mk.1
mv device/xiaomi/chime/lineage_chime.mk.1 device/xiaomi/chime/lineage_chime.mk
cat device/xiaomi/chime/lineage_chime.mk | grep -v WITH_GAPPS > device/xiaomi/chime/lineage_chime.mk.1
mv device/xiaomi/chime/lineage_chime.mk.1 device/xiaomi/chime/lineage_chime.mk
echo 'WITH_GAPPS := true' >> device/xiaomi/chime/lineage_chime.mk
echo 'WITH_GMS := true' >> device/xiaomi/chime/lineage_chime.mk
echo 'RESERVE_SPACE_FOR_GAPPS := false' >> device/xiaomi/chime/lineage_chime.mk

echo 'persist.sys.activity_anim_perf_override=true' >> device/xiaomi/chime/configs/props/product.prop
echo 'PERF_ANIM_OVERRIDE := true' >> device/xiaomi/chime/device.mk
echo 'PERF_ANIM_OVERRIDE := true' >> device/xiaomi/chime/BoardConfig.mk

cat device/xiaomi/chime/BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > device/xiaomi/chime/BoardConfig.mk.1
mv device/xiaomi/chime/BoardConfig.mk.1 device/xiaomi/chime/BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> device/xiaomi/chime/BoardConfig.mk
echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> device/xiaomi/chime/BoardConfig.mk

echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/device.mk

cp device/xiaomi/chime/lineage_chime.mk device/xiaomi/chime/custom_chime.mk

echo "PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false" >> device/xiaomi/chime/device.mk

# Get and decrypt signing keys
curl -o keys.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/BinlFm0d0LoeeibAVCofXsbYTCtcRHpo
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > keys.tar
tar xf keys.tar
rm -f keys.1 keys.2 keys.tar

set +v

#delete some hardware repos not needed for this device to try free up ram for soong.
cd device
rm -rf amlogic  common  generic  google  google_car  linaro  sample
cd ..
repo sync -l device/google/cuttlefish device/generic/goldfish device/generic/car device/generic/trusty device/sample
cd hardware
rm -rf broadcom knowles nxp samsung synaptics telink ti
cd ..
cd hardware/qcom-caf
tar cf ../qcom-caf-bak.tar bootctrl common sm8250 thermal thermal-legacy-um wlan
rm -rf *
tar xf ../qcom-caf-bak.tar ; rm ../qcom-caf-bak.tar
cd ..
cd google
tar cf ../hardware_google.tar gfxstream apf pixel/Android.bp pixel/pixelstats pixel/power-libperfmgr interfaces/Android.bp interfaces/bluetooth/ interfaces/power
rm -rf *
tar xf ../hardware_google.tar ; rm -rf ../hardware_google.tar
cd ../../
rm -rf kernel/tests
rm -rf hardware/qcom

source build/envsetup.sh          ; check_fail
source build/envsetup.sh
export BUILD_USERNAME=user BUILD_HOSTNAME=localhost
export KBUILD_BUILD_USER=user KBUILD_BUILD_HOST=localhost
lunch custom_chime-cp2a-user

export TG_URL
( sleep 3600;
  if pgrep soong_build || { sleep 600; pgrep soong_build; } ; then
    curl -s -X POST $TG_URL -d chat_id=$TG_CID -d text="crave.io build failed. soong timed out after limit. `date`. JJ_SPEC:$JJ_SPEC" > /dev/null 2>&1 ;
    curl -s -d "crave.io build failed. soong timed out after limit. `date`. JJ_SPEC:$JJ_SPEC" "ntfy.sh/$NTFYSUB" > /dev/null 2>&1 ;
    rm -rf /tmp/src/android/vendor/lineage-priv ;
    kill -9 $$ ;
  fi
) &

export GOGC=15
refreshmod || refreshmod 
check_fail
touch soong_done
unset GOGC

# Build it
mka installclean
mka pixelos -j$(nproc --all) ; check_fail

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

# Generate and send OTA json file
curl -o genota.sh -L https://raw.githubusercontent.com/Joe7500/Builds/refs/heads/main/genota.sh
bash genota.sh "$GENOTA_ARG_1" "$GENOTA_ARG_2" "$GO_FILE"
curl -L -F document=@"$GO_FILE.json.txt" -F caption="OTA $GO_FILE.json.txt" -F chat_id="$TG_CID" -X POST https://api.telegram.org/bot$TG_TOKEN/sendDocument > /dev/null 2>&1
rm -f genota.sh

TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
notify_send "Build $PACKAGE_NAME on crave.io completed. $TIME_TAKEN."

cleanup_self
exit 0
