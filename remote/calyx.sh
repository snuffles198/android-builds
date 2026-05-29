#!/bin/bash

source ~/android-builds/dev-secrets/telegram.sh
source ~/android-builds/dev-secrets/secrets.sh
source ~/android-builds/dev-secrets/ntfy.sh
source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc

mkdir -p /tmp/src
if [ ! -d /tmp/src/android ] || [ -L /tmp/src/android ]; then
   rm -rf /tmp/src/android
   ln -s "$PWD" /tmp/src/android
fi

cd /tmp/src/android/

set -v

# Template helper variables
PACKAGE_NAME=calyx
VARIANT_NAME=user
BUILD_TYPE=vanilla
DEVICE_BRANCH=lineage-23.2
VENDOR_BRANCH=lineage-23.2
XIAOMI_BRANCH=lineage-23.2
REPO_URL="-u https://gitlab.com/CalyxOS/platform_manifest -b android16-qpr2 --git-lfs --depth=1 --no-tags --no-clone-bundle "
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
   cd /tmp/src/android/
   rm -rf vendor/lineage-priv/keys vendor/lineage-priv priv-keys
   rm -rf .config/b2/ /home/admin/.config/b2/
   cd packages/apps/Updater/ && git reset --hard && cd ../../../
   cd packages/modules/Connectivity/ && git reset --hard && cd ../../../
   rm -rf prebuilts/clang/kernel/linux-x86/clang-stablekern/ prebuilts/clang/host/linux-x86/clang-stablekern/
   rm -rf hardware/xiaomi/ device/xiaomi/chime/ vendor/xiaomi/chime/ kernel/xiaomi/chime/
   rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml* builder.sh goupload.sh GOFILE.txt
   rm -rf /tmp/android-certs* /home/admin/venv/ custom_scripts/
   cd /home/admin
   rm -rf .tdl LICENSE  README.md  README_zh.md  tdl  tdl_key  tdl_Linux_64bit.tar.gz* venv tdl.zip tdl_Linux.tgz tdl.sh
   cd /tmp/src/android/
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

TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
notify_send "Build $PACKAGE_NAME on crave.io repo sync done. $TIME_TAKEN."

# Download trees
rm -rf kernel/xiaomi/chime/ vendor/xiaomi/chime/ device/xiaomi/chime/ hardware/xiaomi/
rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
curl -C - -o kernel.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/kernel-prebuilt-perf-valeryn-A16.tar.xz" ; check_fail
tar xf kernel.tar.xz ; check_fail
rm -f kernel.tar.xz
curl -C - -o lineage-22.1.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/lineage-22.1.tar.xz" ; check_fail
tar xf lineage-22.1.tar.xz ; check_fail
rm -f lineage-22.1.tar.xz
curl -C - -o toolchain.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/toolchain.tar.xz" ; check_fail
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
cp packages/apps/Updater/res/values/config.xml strings.xml
cat strings.xml | sed -e "s#$OTA_SED_STRING#$OTA_SED_REPLACE_STRING#g" > strings.xml.1
cp strings.xml.1 packages/apps/Updater/res/values/config.xml
check_fail

#git clone https://android.googlesource.com/platform/external/tinyxml external/tinyxml
#cd external/tinyxml
#git revert --no-edit 6e88470e56d725d4dc4225f0218a5bb09a009953
#cd ../../

#curl -o hardware_calyx_interfaces_power-libperfmgr.tgz -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/hardware_calyx_interfaces_power-libperfmgr.tgz
#tar xf hardware_calyx_interfaces_power-libperfmgr.tgz
#rm -f hardware_calyx_interfaces_power-libperfmgr.tgz

sed -i -e 's#ifeq ($(call is-version-lower-or-equal,$(TARGET_KERNEL_VERSION),6.1),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/calyx/build/tasks/kernel.mk
sed -i -e 's#ifeq ($(call is-version-greater-or-equal,$(TARGET_KERNEL_VERSION),5.15),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/calyx/build/tasks/kernel.mk
sed -i -e 's#GKI_SUFFIX := /$(shell echo android$(PLATFORM_VERSION)-$(TARGET_KERNEL_VERSION))#NOT_NEEDED_DISCARD_567 := true#g' vendor/calyx/build/tasks/kernel.mk

grep activity_anim_perf_override frameworks/base/core/java/android/view/animation/AnimationUtils.java
if [ $? -ne 0 ] ; then
   cd frameworks/base/
  curl -o 1.patch -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/AnimUtils-A16-QPR2.java.patch
  patch -p 1 -f < 1.patch ; check_fail
  cd ../../
fi

rm -rf device/motorola/sm6375-common/
rm -rf vendor/qcom/opensource/power
rm -rf device/motorola/
rm -rf sign/

# Android auto prebuilts not included. Extract from official ota package.
if ! ls vendor/google/gearhead/proprietary/; then
export   DEVON_URL=`curl -s https://calyxos.org/get/ota/ | grep devon-ota_update | cut -d '"' -f 2 | head -1`
   curl -C - -o devon.zip -L "$DEVON_URL" ; check_fail
   sudo apt update
   sudo apt -y install 7zip
   sudo apt -y install erofs-utils
   virtualenv dumpyara
   dumpyara/bin/pip install dumpyara
   dumpyara/bin/dumpyara devon.zip
   cd device/google/gearhead/
   ./extract-files.py /tmp/src/android/devon
   cd ../../../
   rm -rf devon dumpyara devon.zip
fi

# Setup device tree
cd device/xiaomi/chime/

git revert --no-edit f29fff90142578384ae8738c4ac55d784c7ed6ba
git revert --no-edit 0a790d4fabf2745212e827d5868f9703b2ec47ed #blur by defaut

curl -o device/xiaomi/chime/configs/powerhint.json -L "https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/powerhint.json.axion.7.txt" ; check_fail

echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> BoardConfig.mk

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
cat device.mk | grep -v 'libdng_sdk.vendor ' > device.mk.1
mv device.mk.1 device.mk
cat device.mk | grep -v 'libtinyxml ' > device.mk.1
mv device.mk.1 device.mk
cat device.mk | sed -e 's#hardware/lineage/interfaces/power-libperfmgr#hardware/calyx/interfaces/power-libperfmgr#g' > device.mk.1
mv device.mk.1 device.mk

cat BoardConfig.mk | sed -e s#vendor/lineage/config/device_framework_matrix.xml#vendor/calyx/config/device_framework_matrix.xml#g > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk
cat BoardConfig.mk | sed -e s#device/lineage/sepolicy/libperfmgr/sepolicy.mk#device/calyx/sepolicy/libperfmgr/sepolicy.mk#g > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk

#echo 'BUILD_BROKEN_PREBUILT_ELF_FILES := true' >> BoardConfig.mk
#echo 'TARGET_DISABLE_EPPE := true' >> BoardConfig.mk

echo 'PRODUCT_PACKAGES += Updater' >> device.mk

cat BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> BoardConfig.mk

echo 'allow platform_app ota_package_file:dir { add_name search write read };' > sepolicy/private/platform_app.te

cd ../../../

# Kernel setup
#cd kernel/xiaomi/chime/
#bash do_ksun-susfs.sh ; check_fail
#cd ../../../

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
tar xvf keys.tar
rm -f keys.1 keys.2 keys.tar
cp keys/chime/com.android.btservices.pem keys/chime/com.android.bt.pem
cp keys/chime/com.android.btservices.pk8 keys/chime/com.android.bt.pk8
cp keys/chime/com.android.btservices.x509.pem keys/chime/com.android.bt.x509.pem
cp keys/chime/com.android.btservices.avbpubkey keys/chime/com.android.bt.avbpubkey
cp keys/chime/com.android.btservices.pem keys/chime/com.android.crashrecovery.pem
cp keys/chime/com.android.btservices.pk8 keys/chime/com.android.crashrecovery.pk8
cp keys/chime/com.android.btservices.x509.pem keys/chime/com.android.crashrecovery.x509.pem
cp keys/chime/com.android.btservices.avbpubkey keys/chime/com.android.crashrecovery.avbpubkey
cp keys/chime/com.android.btservices.pem keys/chime/com.android.uprobestats.pem
cp keys/chime/com.android.btservices.pk8 keys/chime/com.android.uprobestats.pk8
cp keys/chime/com.android.btservices.x509.pem keys/chime/com.android.uprobestats.x509.pem
cp keys/chime/com.android.btservices.avbpubkey keys/chime/com.android.uprobestats.avbpubkey

cp ../out/target/product/chime/otatools.zip .
unzip otatools.zip
rm -f sign/releasetools/Android.bp
rm -f sign/releasetools/merge/Android.bp
cp ../out/target/product/chime/obj/PACKAGING/target_files_intermediates/*.zip .

sed -i s/comet/chime/g vendor/calyx/scripts/release.sh
sed -i 's#BOOTLOADER=$(unzip -c "$TARGET_FILES" OTA/android-info.txt | grep version-bootloader | cut -d = -f 2)#echo hello#g' vendor/calyx/scripts/release.sh
sed -i 's#RADIO=$(unzip -c "$TARGET_FILES" OTA/android-info.txt | grep version-baseband | cut -d = -f 2)#echo hello#g' vendor/calyx/scripts/release.sh

chmod u+x ./vendor/calyx/scripts/release.sh
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
cd /tmp/src/android/
GO_FILE="CalyxOS-chime-$BUILD_NUMBER.zip"
/home/admin/tdl upload -c $TDL_CHAT_ID -p "$GO_FILE"
cd /home/admin
rm -rf .tdl
rm -rf  LICENSE  README.md  README_zh.md  tdl  tdl_key  tdl_Linux_64bit.tar.gz* venv
rm -f tdl.sh
cd /tmp/src/android/

TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
notify_send "Build $PACKAGE_NAME on crave.io completed. $TIME_TAKEN."

cleanup_self
exit 0
