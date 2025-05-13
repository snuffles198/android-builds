#!/bin/bash

set -v

base_root=`pwd`

# Setup
#rm -rf `ls -d * | grep -v tar.xz | grep -v tar.gz`
#rm -rf `ls * | grep -v tar.xz | grep -v tar.gz`

sudo apt install --yes python3

rm -rf work kernel.tar.xz* toolchain.tar.xz* toolchain

if ! ls toolchain.tar.xz ; then
  wget https://github.com/Joe7500/Builds/releases/download/Stuff/kernel.tar.xz || exit 1
  wget https://github.com/Joe7500/Builds/releases/download/Stuff/toolchain.tar.xz || exit 1
fi

rm -rf work
mkdir work
cd $base_root/work

if ! ls ../kernel.tar.gz; then
  tar xf ../kernel.tar.xz
  cd kernel/xiaomi/chime && tar czf ../../../../kernel.tar.gz . && cd ../../..
  if [ $? -ne 0 ]; then exit 1 ; fi
  rm -rf kernel/xiaomi/chime
fi

tar xf ../toolchain.tar.xz
mv prebuilts/clang/host/linux-x86/clang-stablekern/ toolchain
mv toolchain ../
rm -rf prebuilts

# Begin vanilla
tar xf ../kernel.tar.gz
mv ../toolchain .
cat arch/arm64/configs/vendor/xiaomi/bengal_defconfig | grep -v "CONFIG_KSU=y" > arch/arm64/configs/vendor/xiaomi/bengal_defconfig.1
mv arch/arm64/configs/vendor/xiaomi/bengal_defconfig.1 arch/arm64/configs/vendor/xiaomi/bengal_defconfig

echo 'CONFIG_SCHED_DEBUG=y' >> kernel/xiaomi/chime/arch/arm64/configs/vendor/chime_defconfig

bash KernelSU-Next/kernel/setup.sh --cleanup
bash KernelSU/kernel/setup.sh --cleanup

cat hani-ci.sh | grep -v KBUILD_BUILD_USER > hani-ci.sh.1
mv hani-ci.sh.1 hani-ci.sh
cat hani-ci.sh | grep -v KBUILD_BUILD_HOST > hani-ci.sh.1
mv hani-ci.sh.1 hani-ci.sh
export KBUILD_BUILD_USER=user
export KBUILD_BUILD_HOST=localhost

wget https://github.com/Joe7500/build-scripts/raw/refs/heads/main/kernel/anykernel3.tar.gz
tar xf anykernel3.tar.gz

# Build it
bash hani-ci.sh --build || exit 1

# Cleanup
mv 4.19*.zip ../
ls -l ../4.19*.zip
wget https://github.com/Joe7500/Builds/blob/main/crave/gofile.sh || exit 0
mv toolchain ../
#rm -rf *


# Begin KSU

