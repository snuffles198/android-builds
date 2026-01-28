#!/bin/bash

source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc

cd /tmp/src/android/

set -v

# Template helper variables
PACKAGE_NAME=voltage
VARIANT_NAME=user
BUILD_TYPE=vanilla
DEVICE_BRANCH=lineage-22.2
VENDOR_BRANCH=lineage-22.2
XIAOMI_BRANCH=lineage-22.2
REPO_URL="-u https://github.com/VoltageOS/manifest.git -b 15-qpr2 --git-lfs"
OTA_SED_STRING="https://raw.githubusercontent.com/VoltageOS/android_vendor_voltageota/15-qpr2/{device}.json"
OTA_SED_REPLACE_STRING="https://raw.githubusercontent.com/Joe7500/Builds/main/$PACKAGE_NAME.$VARIANT_NAME.chime.json"

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
   cd vendor/voltage-priv/keys && rm -rf * && git reset --hard && cd /tmp/src/android/
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
   /opt/crave/resync.sh ; check_fail
fi

# Download trees
rm -rf kernel/xiaomi/chime/
rm -rf vendor/xiaomi/chime/
rm -rf device/xiaomi/chime/
rm -rf hardware/xiaomi/
rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
curl -o kernel.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/kernel.tar.xz" ; check_fail
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
cat strings.xml | sed -e "s#$OTA_SED_STRING#$OTA_SED_REPLACE_STRING#g" > strings.xml.1
cp strings.xml.1 packages/apps/Updater/app/src/main/res/values/strings.xml
check_fail

cd external 
rm -rf wpa_supplicant_8
git clone https://github.com/LineageOS/android_external_wpa_supplicant_8.git -b lineage-22.2 wpa_supplicant_8
cd ..

cat frameworks/base/packages/SystemUI/res/values/dimens.xml | sed -e 's#<dimen name="qs_media_seekbar_progress_amplitude">1.5dp</dimen>#<dimen name="qs_media_seekbar_progress_amplitude">0dp</dimen>#g' > frameworks/base/packages/SystemUI/res/values/dimens.xml.1
mv frameworks/base/packages/SystemUI/res/values/dimens.xml.1 frameworks/base/packages/SystemUI/res/values/dimens.xml

curl -o voltage_brightness_slider.patch -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/src/voltage_brightness_slider.patch
cd packages/apps/Powerhub/
git reset --hard
patch -f -p 1 < ../../../voltage_brightness_slider.patch
cd ../../../

rm -f hardware/qcom/sm7250/Android.bp hardware/qcom/sm7250/Android.mk
rm -f hardware/qcom/sdm845/Android.bp hardware/qcom/sdm845/Android.mk
rm -f hardware/qcom/sm8150/Android.bp hardware/qcom/sm8150/Android.mk

# Setup device tree
cat device/xiaomi/chime/BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > device/xiaomi/chime/BoardConfig.mk.1
mv device/xiaomi/chime/BoardConfig.mk.1 device/xiaomi/chime/BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> device/xiaomi/chime/BoardConfig.mk

cd device/xiaomi/chime/

git revert --no-edit 6cece0c9cf6aa7d4ed5380605fed9b90f63c250c

cat device.mk | sed -e 's#vendor/lineage-priv/keys/keys.mk#vendor/voltage-priv/keys/keys.mk#g' > device.mk.1
mv device.mk.1 device.mk
cat AndroidProducts.mk | sed -e s/lineage/voltage/g > AndroidProducts.mk.1
mv AndroidProducts.mk.1 AndroidProducts.mk

#cat BoardConfig.mk | sed -e s#vendor/lineage/config/device_framework_matrix.xml#vendor/voltage/config/device_framework_matrix.xml#g > BoardConfig.mk.1
#cat BoardConfig.mk | grep -iv 'vendor/lineage/config/device_framework_matrix.xml' > BoardConfig.mk.1
#mv BoardConfig.mk.1 BoardConfig.mk
curl -o lineage_frame.xml -L https://raw.githubusercontent.com/LineageOS/android_vendor_lineage/refs/heads/lineage-22.2/config/device_framework_matrix.xml
mkdir ../../../vendor/lineage
mkdir ../../../vendor/lineage/config
mv lineage_frame.xml ../../../vendor/lineage/config/device_framework_matrix.xml

cat BoardConfig.mk | sed -e s#device/lineage/sepolicy/libperfmgr/sepolicy.mk#device/voltage/sepolicy/libperfmgr/sepolicy.mk#g > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk
cat lineage_chime.mk | sed -e s/lineage/voltage/g > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
mv lineage_chime.mk voltage_chime.mk
echo 'BUILD_BROKEN_PREBUILT_ELF_FILES := true' >> BoardConfig.mk
echo 'TARGET_DISABLE_EPPE := true' >> BoardConfig.mk
echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> BoardConfig.mk

mkdir --parents overlay-lineage/packages/apps/Settings/res/values
echo '<?xml version="1.0" encoding="utf-8"?>' > overlay-lineage/packages/apps/Settings/res/values/voltage_strings.xml
echo '<resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">' >> overlay-lineage/packages/apps/Settings/res/values/voltage_strings.xml
echo '<string name="voltage_maintainer">Joe</string>' >> overlay-lineage/packages/apps/Settings/res/values/voltage_strings.xml
echo '</resources>' >> overlay-lineage/packages/apps/Settings/res/values/voltage_strings.xml

#cat overlay-lineage/frameworks/base/packages/SystemUI/res/values/config.xml | grep -v '</resources>' > overlay-lineage/frameworks/base/packages/SystemUI/res/values/config.xml.1
#echo '    <string name="qs_brightness_slider_position">0</string>' >> overlay-lineage/frameworks/base/packages/SystemUI/res/values/config.xml.1
#echo '</resources>' >> overlay-lineage/frameworks/base/packages/SystemUI/res/values/config.xml.1
#mv overlay-lineage/frameworks/base/packages/SystemUI/res/values/config.xml.1 overlay-lineage/frameworks/base/packages/SystemUI/res/values/config.xml

cd ../../../

# Kernel setup
cd kernel/xiaomi/chime/
bash do_ksun-susfs.sh ; check_fail
cd ../../../

# Get dev secrets from bucket.
sudo apt --yes install python3-virtualenv virtualenv python3-pip-whl
rm -rf /home/admin/venv
virtualenv /home/admin/venv ; check_fail
set +v
source /home/admin/venv/bin/activate
set -v
pip install --upgrade b2 ; check_fail
b2 account authorize "$BKEY_ID" "$BAPP_KEY" > /dev/null 2>&1 ; check_fail
mkdir priv-keys
b2 sync "b2://$BUCKET_NAME/voltage-certs" "priv-keys" > /dev/null 2>&1 ; check_fail
b2 sync "b2://$BUCKET_NAME/tdl" "/home/admin" > /dev/null 2>&1 ; check_fail
#mkdir --parents vendor/lineage-priv/keys
mkdir --parents vendor/voltage-priv/keys
#mv priv-keys/* vendor/lineage-priv/keys
mv priv-keys/* vendor/voltage-priv/keys
rm -rf priv-keys
rm -rf .config/b2/
rm -rf /home/admin/.config/b2/
deactivate
unset BUCKET_NAME
unset KEY_ENCRYPTION_PASSWORD
unset BKEY_ID
unset BAPP_KEY
unset KEY_PASSWORD
cat /tmp/crave_bashrc | grep -vE "BKEY_ID|BUCKET_NAME|KEY_ENCRYPTION_PASSWORD|BAPP_KEY|TG_CID|TG_TOKEN" > /tmp/crave_bashrc.1
mv /tmp/crave_bashrc.1 /tmp/crave_bashrc

sleep 10

# Build it
set +v

source build/envsetup.sh          ; check_fail
breakfast chime user              ; check_fail
mka installclean
mka bacon                         ; check_fail

set -v

echo success > result.txt
notify_send "Build $PACKAGE_NAME on crave.io succeeded."

# Upload output to gofile
cp out/target/product/chime/$PACKAGE_NAME*-chime*.zip .
GO_FILE=`ls --color=never -1tr $PACKAGE_NAME*-chime*.zip | tail -1`
GO_FILE_MD5=`md5sum "$GO_FILE"`
GO_FILE=`pwd`/$GO_FILE
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
