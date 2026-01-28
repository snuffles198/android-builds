#!/bin/bash

source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc ; source build/envsetup.sh

croot

set -v

# Template helper variables
PACKAGE_NAME=calyx
VARIANT_NAME=user
BUILD_TYPE=vanilla
DEVICE_BRANCH=lineage-22.2
VENDOR_BRANCH=lineage-22.2
XIAOMI_BRANCH=lineage-22.2
REPO_URL="-u https://gitlab.com/CalyxOS/platform_manifest -b android15-qpr2 --git-lfs"
OTA_SED_STRING="https://release.calyxinstitute.org/"
OTA_SED_REPLACE_STRING="https://github.com/Joe7500/Builds/releases/download/calyx-ota/"

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
   croot
   rm -rf vendor/lineage-priv/keys
   rm -rf vendor/lineage-priv
   rm -rf priv-keys
   rm -rf .config/b2/
   rm -rf /home/admin/.config/b2/
   cd packages/apps/Updater/ && git reset --hard && croot
   cd packages/modules/Connectivity/ && git reset --hard && croot
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
   croot
   rm -rf sign/keys
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
   # Calyx hates these lineage git repos
   rm -rf prebuilts/gcc/
   for i in `find .repo/ | grep 'prebuilts/gcc'`; do
      rm -rf $i
   done
   /opt/crave/resync.sh || /opt/crave/resync.sh
   /opt/crave/resync.sh || /opt/crave/resync.sh ; check_fail
fi

# Download trees
rm -rf kernel/xiaomi/chime/
rm -rf vendor/xiaomi/chime/
rm -rf device/xiaomi/chime/
rm -rf hardware/xiaomi/
rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
curl -o kernel.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/kernel-prebuilt-hanikrnl-susfs.tar.xz" ; check_fail
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
cd packages/modules/Connectivity/ && git reset --hard && croot
patch -f -p 1 < InterfaceController.java.patch ; check_fail
rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml.*
rm -f vendor/xiaomi/chime/proprietary/system_ext/etc/init/wfdservice.rc.rej
rm -f packages/modules/Connectivity/staticlibs/device/com/android/net/module/util/ip/InterfaceController.java.rej

cd packages/apps/Updater/ && git reset --hard && croot
cp packages/apps/Updater/res/values/config.xml strings.xml
cat strings.xml | sed -e "s#$OTA_SED_STRING#$OTA_SED_REPLACE_STRING#g" > strings.xml.1
cp strings.xml.1 packages/apps/Updater/res/values/config.xml
check_fail

git clone https://android.googlesource.com/platform/external/tinyxml external/tinyxml
cd external/tinyxml
git revert --no-edit 6e88470e56d725d4dc4225f0218a5bb09a009953
croot

curl -o hardware_calyx_interfaces_power-libperfmgr.tgz -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/hardware_calyx_interfaces_power-libperfmgr.tgz
tar xf hardware_calyx_interfaces_power-libperfmgr.tgz
rm -f hardware_calyx_interfaces_power-libperfmgr.tgz

rm -rf vendor/qcom/opensource/power
rm -rf device/motorola/
rm -rf sign/

# Android auto prebuilts not included. Extract from official ota package.
if ! ls vendor/google/gearhead/proprietary/; then
   DEVON_URL=`curl -s https://calyxos.org/get/ota/ | grep devon-ota_update | cut -d '"' -f 2 | head -1`
   curl -o devon.zip -L "$DEVON_URL"
   sudo apt update
   sudo apt -y install 7zip
   sudo apt -y install erofs-utils
   virtualenv dumpyara
   dumpyara/bin/pip install dumpyara
   dumpyara/bin/dumpyara devon.zip
   cd device/google/gearhead/
   ./extract-files.py /tmp/src/android/devon
   croot
   rm -rf devon dumpyara devon.zip
fi

# Setup device tree
echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> device/xiaomi/chime/BoardConfig.mk

cd device/xiaomi/chime/

git revert --no-edit f29fff90142578384ae8738c4ac55d784c7ed6ba

cat AndroidProducts.mk | sed -e s/lineage/calyx/g > AndroidProducts.mk.1
mv AndroidProducts.mk.1 AndroidProducts.mk

cat lineage_chime.mk | sed -e s/lineage/calyx/g > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
cat lineage_chime.mk | sed -e s/common_full_phone.mk/common_phone.mk/g > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
cat lineage_chime.mk | grep -v "RESERVE_SPACE_FOR_GAPPS" > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
echo "RESERVE_SPACE_FOR_GAPPS := false" >> lineage_chime.mk
mv lineage_chime.mk calyx_chime.mk

cat Android.bp | sed -e 's#hardware/lineage/interfaces/power-libperfmgr#hardware/calyx/interfaces/power-libperfmgr#g' > Android.bp.1
mv Android.bp.1 Android.bp

cat device.mk | grep -v libstdc++_vendor > device.mk.1
mv device.mk.1 device.mk
cat device.mk | grep -v 'vendor/lineage-priv/keys/keys.mk' > device.mk.1
mv device.mk.1 device.mk
cat device.mk | sed -e 's#hardware/lineage/interfaces/power-libperfmgr#hardware/calyx/interfaces/power-libperfmgr#g' > device.mk.1
mv device.mk.1 device.mk

cat BoardConfig.mk | sed -e s#vendor/lineage/config/device_framework_matrix.xml#vendor/calyx/config/device_framework_matrix.xml#g > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk
cat BoardConfig.mk | sed -e s#device/lineage/sepolicy/libperfmgr/sepolicy.mk#device/calyx/sepolicy/libperfmgr/sepolicy.mk#g > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk

#rm -f releasetools.py
#curl -o releasetools.py -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/calyx_releasetools.py

echo 'BUILD_BROKEN_PREBUILT_ELF_FILES := true' >> BoardConfig.mk
echo 'TARGET_DISABLE_EPPE := true' >> BoardConfig.mk

echo 'PRODUCT_PACKAGES += Updater' >> device.mk

croot

cat device/xiaomi/chime/BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > device/xiaomi/chime/BoardConfig.mk.1
mv device/xiaomi/chime/BoardConfig.mk.1 device/xiaomi/chime/BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> device/xiaomi/chime/BoardConfig.mk

echo 'allow platform_app ota_package_file:dir { add_name search write read };' > device/xiaomi/chime/sepolicy/private/platform_app.te

# Kernel setup
#cd kernel/xiaomi/chime/
#bash do_ksun-susfs.sh ; check_fail
#croot

# Build it
set +v

source build/envsetup.sh          ; check_fail
breakfast chime user              ; check_fail
m installclean
m                         ; check_fail
m target-files-package
m otatools-package otatools-keys-package

set -v

# Sign release and make ota package
rm -rf sign
mkdir sign
cd sign

curl -o keys.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/jcalKK1oHiBRBrMv1k6iAKnKy80pY9QX
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > keys.tar
tar xf keys.tar
rm -f keys.1 keys.2 keys.tar

cp ../out/target/product/chime/otatools.zip .
unzip otatools.zip
cp ../out/target/product/chime/obj/PACKAGING/target_files_intermediates/*.zip .

cat vendor/calyx/scripts/release.sh | sed -e s/comet/chime/g > vendor/calyx/scripts/release.sh.1
mv vendor/calyx/scripts/release.sh.1 vendor/calyx/scripts/release.sh
chmod u+x ./vendor/calyx/scripts/release.sh
#export BUILD_NUMBER=$(date '+%d-%m-%Y')
export BUILD_NUMBER=`bash ../calyx/scripts/release/version.sh`
./vendor/calyx/scripts/release.sh chime calyx_chime-target_files.zip

OTA_FILE=`find out/ | grep chime-ota_update | grep -v sum`
FACTORY_FILE=`find out/ | grep chime-factory | grep -v sum`
cp $OTA_FILE ../CalyxOS-chime-$BUILD_NUMBER.zip
cp $FACTORY_FILE ../CalyxOS-chime-factory-$BUILD_NUMBER.zip
cd ..
rm -rf sign/keys

echo success > result.txt
notify_send "Build $PACKAGE_NAME on crave.io succeeded."

# Upload output to gofile
GO_FILE_MD5=`md5sum "CalyxOS-chime-$BUILD_NUMBER.zip"`
GO_FILE="CalyxOS-chime-$BUILD_NUMBER.zip"
curl -o goupload.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/utils/gofile.sh
bash goupload.sh $GO_FILE
GO_LINK=`cat GOFILE.txt`
notify_send "MD5:$GO_FILE_MD5 $GO_LINK"
rm -f goupload.sh GOFILE.txt
GO_FILE_MD5=`md5sum "CalyxOS-chime-factory-$BUILD_NUMBER.zip"`
GO_FILE="CalyxOS-chime-factory-$BUILD_NUMBER.zip"
curl -o goupload.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/utils/gofile.sh
bash goupload.sh $GO_FILE
GO_LINK=`cat GOFILE.txt`
notify_send "MD5:$GO_FILE_MD5 $GO_LINK"
rm -f goupload.sh GOFILE.txt

# Upload output to telegram
if [[ ! -f $GO_FILE ]]; then
   GO_FILE=builder.sh
fi
cd /home/admin
curl -o tdl.1  -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/keys/ktdlxIevOo3wGJWrun01W1BzVWvKKZGw
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d tdl.1 > tdl.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d tdl.2 > tdl.tar
tar xf tdl.tar
rm -f tdl.1 tdl.2 tdl.tar
unzip -o -P $TDL_ZIP_PASSWD tdl.zip
rm -f tdl.zip
VERSION=$(curl --silent "https://api.github.com/repos/iyear/tdl/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
wget -O tdl_Linux.tgz https://github.com/iyear/tdl/releases/download/$VERSION/tdl_Linux_64bit.tar.gz ; check_fail
tar xf tdl_Linux.tgz ; check_fail
croot
GO_FILE="CalyxOS-chime-$BUILD_NUMBER.zip"
/home/admin/tdl upload -c $TDL_CHAT_ID -p "$GO_FILE"
cd /home/admin
rm -rf .tdl
rm -rf  LICENSE  README.md  README_zh.md  tdl  tdl_key  tdl_Linux_64bit.tar.gz* venv
rm -f tdl.sh
croot

TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
notify_send "Build $PACKAGE_NAME on crave.io completed. $TIME_TAKEN."

cleanup_self
exit 0
