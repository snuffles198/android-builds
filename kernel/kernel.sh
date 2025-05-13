#!/bin/bash

set -v

base_root=`pwd`

# Setup
#rm -rf `ls -d * | grep -v tar.xz | grep -v tar.gz`
#rm -rf `ls * | grep -v tar.xz | grep -v tar.gz`

echo $PATH
whereis python
ls -l /usr/local/sbin/python*
ls -l /usr/local/bin/python*
ls -l /usr/sbin/python*
ls -l /usr/bin/python*
ls -l /sbin/python*
ls -l /bin/python*

mkdir ~/bin
rm -f ~/bin/python
ln -s /usr/bin/python3 ~/bin/python
export PATH=$PATH:~/bin/

#exit 1

sudo apt install --yes python3

rm -rf work toolchain

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

###
###
###
###
###
# Begin vanilla
tar xf ../kernel.tar.gz
mv ../toolchain .

bash KernelSU-Next/kernel/setup.sh --cleanup
bash KernelSU/kernel/setup.sh --cleanup

cat arch/arm64/configs/vendor/xiaomi/bengal_defconfig | grep -v "CONFIG_KSU=y" > arch/arm64/configs/vendor/xiaomi/bengal_defconfig.1
mv arch/arm64/configs/vendor/xiaomi/bengal_defconfig.1 arch/arm64/configs/vendor/xiaomi/bengal_defconfig

echo 'CONFIG_SCHED_DEBUG=y' >> arch/arm64/configs/vendor/xiaomi/bengal_defconfig

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

# Upload it
KERNEL_PACKAGE=`ls 4.19*.zip`
mv $KERNEL_PACKAGE $KERNEL_PACKAGE.van.zip
GO_FILE=$KERNEL_PACKAGE.van.zip
rm goupload.sh 
curl -o goupload.sh -L https://raw.githubusercontent.com/Joe7500/Builds/refs/heads/main/crave/gofile.sh
bash goupload.sh $GO_FILE
cat GOFILE.txt >> FILES.txt
cat FILES.txt
rm GOFILE.txt

# Cleanup
mv 4.19*.zip ../
mv toolchain ../
cd ..
rm -rf work
mkdir work
cd $base_root/work

###
###
###
###
###
# Begin KSU
tar xf ../kernel.tar.gz
mv ../toolchain .

bash KernelSU-Next/kernel/setup.sh --cleanup
bash KernelSU/kernel/setup.sh --cleanup
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5

echo 'CONFIG_SCHED_DEBUG=y' >> arch/arm64/configs/vendor/xiaomi/bengal_defconfig

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

# Upload it
KERNEL_PACKAGE=`ls 4.19*.zip`
mv $KERNEL_PACKAGE $KERNEL_PACKAGE.ksu.zip
GO_FILE=$KERNEL_PACKAGE.van.zip
rm goupload.sh 
curl -o goupload.sh -L https://raw.githubusercontent.com/Joe7500/Builds/refs/heads/main/crave/gofile.sh
bash goupload.sh $GO_FILE
cat GOFILE.txt >> FILES.txt
cat FILES.txt
rm GOFILE.txt

# Cleanup
mv 4.19*.zip ../
mv toolchain ../
cd ..
rm -rf work
mkdir work
cd $base_root/work

###
###
###
###
###
# Begin KSU-next
tar xf ../kernel.tar.gz
mv ../toolchain .

bash KernelSU-Next/kernel/setup.sh --cleanup
bash KernelSU/kernel/setup.sh --cleanup
curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -

echo 'CONFIG_SCHED_DEBUG=y' >> arch/arm64/configs/vendor/xiaomi/bengal_defconfig

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

# Upload it
KERNEL_PACKAGE=`ls 4.19*.zip`
mv $KERNEL_PACKAGE $KERNEL_PACKAGE.ksu.zip
GO_FILE=$KERNEL_PACKAGE.van.zip
rm goupload.sh 
curl -o goupload.sh -L https://raw.githubusercontent.com/Joe7500/Builds/refs/heads/main/crave/gofile.sh
bash goupload.sh $GO_FILE
cat GOFILE.txt >> FILES.txt
cat FILES.txt
rm GOFILE.txt

# Cleanup
mv 4.19*.zip ../
mv toolchain ../
cd ..
rm -rf work
mkdir work
cd $base_root/work

###
###
###
###
###
# Begin KSU-next-susfs
tar xf ../kernel.tar.gz
mv ../toolchain .

curl -o 05-susfs.patch https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/05-susfs.patch || exit 1
patch -p 1 < 05-susfs.patch
echo 'KSU_SUSFS_HAS_MAGIC_MOUNT=y' >> arch/arm64/configs/vendor/chime_defconfig
echo 'CONFIG_KSU_SUSFS=y' >> arch/arm64/configs/vendor/chime_defconfig
bash KernelSU-Next/kernel/setup.sh --cleanup
bash KernelSU/kernel/setup.sh --cleanup
curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next-susfs/kernel/setup.sh" | bash -s next-susfs

echo 'CONFIG_SCHED_DEBUG=y' >> arch/arm64/configs/vendor/xiaomi/bengal_defconfig

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

# Upload it
KERNEL_PACKAGE=`ls 4.19*.zip`
mv $KERNEL_PACKAGE $KERNEL_PACKAGE.ksu.zip
GO_FILE=$KERNEL_PACKAGE.van.zip
rm goupload.sh 
curl -o goupload.sh -L https://raw.githubusercontent.com/Joe7500/Builds/refs/heads/main/crave/gofile.sh
bash goupload.sh $GO_FILE
cat GOFILE.txt >> FILES.txt
cat FILES.txt
rm GOFILE.txt

# Cleanup
mv 4.19*.zip ../
mv toolchain ../
cd ..
rm -rf work
mkdir work
cd $base_root/work

