#!/bin/bash

source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc

cd /tmp/src/android/

set -v

# Template helper variables
PACKAGE_NAME=MistOS-4
VARIANT_NAME=user
BUILD_TYPE=gapps
DEVICE_BRANCH=lineage-23.0
VENDOR_BRANCH=lineage-23.0
XIAOMI_BRANCH=lineage-23.0
REPO_URL="-u https://github.com/Project-Mist-OS/manifest.git -b 16"
OTA_SED_STRING="MistOS-Devices/official_devices/16/builds/{device}.json"
OTA_SED_REPLACE_STRING="Joe7500/Builds/main/$PACKAGE_NAME.$VARIANT_NAME.chime.json"

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

for i in `grep -R '<string name="unofficial_build_suffix">' packages/apps/Settings/res | cut -d ':' -f 1` ; do
  cat $i | sed -e 's#<string name="unofficial_build_suffix">.*string>#<string name="unofficial_build_suffix">- Community</string>#g' > $i.1
  mv $i.1 $i
done

cd vendor/lineage
git reset --hard
cat config/version.mk | sed -e 's/MIST_BUILD_TYPE ?= Unofficial/MIST_BUILD_TYPE ?= COMMUNITY/g' > config/version.mk.1
mv config/version.mk.1 config/version.mk
cat config/version.mk | sed -e 's/MIST_BUILD_TYPE := UNOFFICIAL/MIST_BUILD_TYPE := COMMUNITY/g' > config/version.mk.1
mv config/version.mk.1 config/version.mk
cd ../..

# Setup device tree
cd device/xiaomi/chime
git switch lineage-23.0
rm -rf *
git reset --hard
export MISTOS_MAINTAINER="Joe"
cat lineage_chime.mk | grep -v "RESERVE_SPACE_FOR_GAPPS" > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
echo "RESERVE_SPACE_FOR_GAPPS := true" >> lineage_chime.mk
echo 'MISTOS_MAINTAINER := Joe' >> lineage_chime.mk
echo 'MISTOS_MAINTAINER="Joe"' >> lineage_chime.mk
echo 'WITH_GMS := false' >> lineage_chime.mk
cd ../../../

echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/device.mk
echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/BoardConfig.mk

cat device/xiaomi/chime/BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > device/xiaomi/chime/BoardConfig.mk.1
mv device/xiaomi/chime/BoardConfig.mk.1 device/xiaomi/chime/BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> device/xiaomi/chime/BoardConfig.mk

echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> device/xiaomi/chime/BoardConfig.mk

# Setup kernel
cd kernel/xiaomi/chime
patch -f -p 1 -R  < sched_param_perf.patch
cd ../../../

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

source build/envsetup.sh          ; check_fail
mistify chime user                ; check_fail
mka installclean
mist b

if [ $? -ne 0 ] && grep sched_param out/error.log ; then
   echo F... kernel sched_param
   notify_send "Build $PACKAGE_NAME on crave.io kernel sched_param."
   cd kernel/xiaomi/chime
   patch -p 1 -t < sched_param.patch
   cd -
   mist b
else
   check_fail
fi

if [ $? -ne 0 ] && grep sched_param out/error.log ; then
   echo F... kernel sched_param
   notify_send "Build $PACKAGE_NAME on crave.io kernel sched_param again."
   cd kernel/xiaomi/chime
   patch -p 1 -t < sched_param.patch
   cd -
   mist b
else
   check_fail
fi

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
cd packages/apps/Updater/ && git reset --hard && cd ../../../
cp packages/apps/Updater/app/src/main/res/values/strings.xml strings.xml
cat strings.xml | sed -e "s#$OTA_SED_STRING#$OTA_SED_REPLACE_STRING.gapps.json#g" > strings.xml.1
cp strings.xml.1 packages/apps/Updater/app/src/main/res/values/strings.xml
check_fail

# Setup device tree
cd device/xiaomi/chime
git switch lineage-23.0
rm -rf *
git reset --hard
export MISTOS_MAINTAINER="Joe"
cat lineage_chime.mk | grep -v "RESERVE_SPACE_FOR_GAPPS" > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
echo "RESERVE_SPACE_FOR_GAPPS := false" >> lineage_chime.mk
echo 'MISTOS_MAINTAINER := Joe' >> lineage_chime.mk
echo 'MISTOS_MAINTAINER="Joe"' >> lineage_chime.mk
echo 'WITH_GMS := true' >> lineage_chime.mk
cd ../../../

echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/device.mk
echo 'TARGET_DISABLE_EPPE := true' >> device/xiaomi/chime/BoardConfig.mk

cat device/xiaomi/chime/BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > device/xiaomi/chime/BoardConfig.mk.1
mv device/xiaomi/chime/BoardConfig.mk.1 device/xiaomi/chime/BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> device/xiaomi/chime/BoardConfig.mk

echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> device/xiaomi/chime/BoardConfig.mk

# Build it
set +v

source build/envsetup.sh          ; check_fail
mistify chime user                ; check_fail
mka installclean
mist b

if [ $? -ne 0 ] && grep sched_param out/error.log ; then
   echo F... kernel sched_param
   notify_send "Build $PACKAGE_NAME GAPPS on crave.io kernel sched_param."
   cd kernel/xiaomi/chime
   patch -p 1 -t < sched_param.patch
   cd -
   mist b
else
   check_fail
fi

if [ $? -ne 0 ] && grep sched_param out/error.log ; then
   echo F... kernel sched_param
   notify_send "Build $PACKAGE_NAME GAPPS on crave.io kernel sched_param again."
   cd kernel/xiaomi/chime
   patch -p 1 -t < sched_param.patch
   cd -
   mist b
else
   check_fail
fi

set -v

# Upload output to gofile
cp out/target/product/chime/$PACKAGE_NAME*GAPPS*.zip .
GO_FILE=`ls --color=never -1tr $PACKAGE_NAME*GAPPS*.zip | tail -1`
GO_FILE_MD5=`md5sum "$GO_FILE"`
GO_FILE=`pwd`/$GO_FILE
curl -o goupload.sh -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/utils/gofile.sh
bash goupload.sh $GO_FILE
GO_LINK=`cat GOFILE.txt`
notify_send "MD5:$GO_FILE_MD5 $GO_LINK"
rm -f goupload.sh GOFILE.txt

# Upload output to telegram

TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
notify_send "Build $PACKAGE_NAME GAPPS on crave.io completed. $TIME_TAKEN."

cleanup_self
exit 0
