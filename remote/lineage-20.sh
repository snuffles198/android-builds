#!/bin/bash

source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc ; source build/envsetup.sh

croot

set -v

# Template helper variables
PACKAGE_NAME=lineage-20
VARIANT_NAME=user
BUILD_TYPE=vanilla
DEVICE_BRANCH=13.0
VENDOR_BRANCH=13.0
XIAOMI_BRANCH=lineage-20
GENOTA_ARG_1="lineage"
GENOTA_ARG_2="20"
REPO_URL="-u https://github.com/LineageOS/android.git -b lineage-20.0 --git-lfs"
OTA_SED_STRING="https://download.lineageos.org/api/v1/{device}/{type}/{incr}"
OTA_SED_REPLACE_STRING="https://raw.githubusercontent.com/Joe7500/Builds/main/$PACKAGE_NAME.$VARIANT_NAME.chime.json"
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
   croot
   rm -rf vendor/lineage-priv/keys vendor/lineage-priv  priv-keys
   rm -rf .config/b2/ /home/admin/.config/b2/
   cd packages/apps/Updater/ && git reset --hard && croot
   cd packages/modules/Connectivity/ && git reset --hard && croot
   rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
   rm -rf hardware/xiaomi/ device/xiaomi/chime/ vendor/xiaomi/chime/ kernel/xiaomi/chime/
   rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml* builder.sh goupload.sh GOFILE.txt
   rm -rf /tmp/android-certs* /home/admin/venv/ custom_scripts/
   cd /home/admin
   rm -rf .tdl LICENSE  README.md  README_zh.md  tdl  tdl_key  tdl_Linux_64bit.tar.gz* venv tdl.zip tdl_Linux.tgz tdl.sh
   croot
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
   repo init $REPO_URL --git-lfs ; check_fail
   cleanup_self
   /opt/crave/resync.sh ; check_fail
fi

# Download trees
rm -rf kernel/xiaomi/chime/
rm -rf vendor/xiaomi/chime/
rm -rf device/xiaomi/chime/
rm -rf hardware/xiaomi/
rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
curl -o kernel.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/kernel-prebuilt-perf-lilium-ksu.tar.xz" ; check_fail
tar xf kernel.tar.xz ; check_fail
rm -f kernel.tar.xz
curl -o lineage-22.1.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/lineage-22.1.tar.xz" ; check_fail
tar xf lineage-22.1.tar.xz ; check_fail
rm -f lineage-22.1.tar.xz
curl -o toolchain.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/toolchain.tar.xz" ; check_fail
tar xf toolchain.tar.xz ; check_fail
rm -f toolchain.tar.xz
git clone https://github.com/crdroidandroid/android_device_xiaomi_chime.git -b $DEVICE_BRANCH device/xiaomi/chime ; check_fail
git clone https://github.com/crdroidandroid/android_vendor_xiaomi_chime.git -b $VENDOR_BRANCH vendor/xiaomi/chime ; check_fail
git clone https://github.com/LineageOS/android_hardware_xiaomi -b $XIAOMI_BRANCH hardware/xiaomi ; check_fail

# prebuilts/clang/host/linux-x86/clang-3289846/bin/clang.real: error while loading shared libraries: libncurses.so.5: cannot open shared object file: No such file or directory
curl -o libncurses-5.tar.xz -L https://github.com/snuffles198/android-builds/raw/refs/heads/main/remote/utils/libncurses-5.tar.xz; check_fail
tar xvf libncurses-5.tar.xz ; check_fail
sudo dpkg -i --force-all libncurses5_6.3-2ubuntu0.1_amd64.deb libtinfo5_6.3-2ubuntu0.1_amd64.deb
rm -f libncurses-5.tar.xz libncurses5_6.3-2ubuntu0.1_amd64.deb libtinfo5_6.3-2ubuntu0.1_amd64.deb

# Setup AOSP source 
#patch -f -p 1 < wfdservice.rc.patch ; check_fail
#cd packages/modules/Connectivity/ && git reset --hard && croot
#patch -f -p 1 < InterfaceController.java.patch ; check_fail
rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml.*
rm -f vendor/xiaomi/chime/proprietary/system_ext/etc/init/wfdservice.rc.rej
rm -f packages/modules/Connectivity/staticlibs/device/com/android/net/module/util/ip/InterfaceController.java.rej

cd packages/apps/Updater/ && git reset --hard && croot
cp packages/apps/Updater/app/src/main/res/values/strings.xml strings.xml
cat strings.xml | sed -e "s#$OTA_SED_STRING#$OTA_SED_REPLACE_STRING#g" > strings.xml.1
cp strings.xml.1 packages/apps/Updater/app/src/main/res/values/strings.xml
check_fail

# Setup device tree
cat device/xiaomi/chime/BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > device/xiaomi/chime/BoardConfig.mk.1
mv device/xiaomi/chime/BoardConfig.mk.1 device/xiaomi/chime/BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> device/xiaomi/chime/BoardConfig.mk

cat device/xiaomi/chime/device.mk | grep -v "vendor/lineage-priv/keys/keys.mk" > device/xiaomi/chime/device.mk.1
mv device/xiaomi/chime/device.mk.1 device/xiaomi/chime/device.mk
echo 'include vendor/lineage-priv/keys/keys.mk' >> device/xiaomi/chime/device.mk

echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> device/xiaomi/chime/BoardConfig.mk

# Setup kernel
cd kernel/xiaomi/chime
patch -f -p 1 -R  < sched_param_perf.patch
croot

# Get and decrypt signing keys
curl -o keys.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/BinlFm0d0LoeeibAVCofXsbYTCtcRHpo
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > keys.tar
tar xf keys.tar
rm -f keys.1 keys.2 keys.tar

# Build it
set +v

source build/envsetup.sh          ; check_fail
export BUILD_USERNAME=user
export BUILD_HOSTNAME=localhost
export KBUILD_BUILD_USER=user
export KBUILD_BUILD_HOST=localhost
breakfast chime user              ; check_fail
mka installclean
mka bacon                         ; check_fail

set -v

echo success > result.txt
notify_send "Build $PACKAGE_NAME on crave.io succeeded."

# Upload output to pixeldrain
cp out/target/product/chime/$PACKAGE_NAME*.zip .
GO_FILE=`ls --color=never -1tr $PACKAGE_NAME*.zip | tail -1`
GO_FILE_MD5=`md5sum "$GO_FILE"`
echo "$GO_FILE"
if [[ ! -f $GO_FILE ]]; then
   GO_FILE=builder.sh
fi
curl -s -L -T "$GO_FILE" -u ":$PDAPIKEY" https://pixeldrain.com/api/file/ > out.json
PD_ID=`cat out.json | cut -d '"' -f 4`
notify_send "MD5:$GO_FILE_MD5 https://pixeldrain.com/u/$PD_ID"

# Upload file to SF
curl -s -o keys.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/usfJoFvObArLx0KmBzwerPPTzliixTN2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > sf
chmod a-x sf
chmod go-rwx sf
rsync --log-file=rsync.log -avP -e 'ssh -i ./sf -o "StrictHostKeyChecking accept-new"' $GO_FILE $SF_URL
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
