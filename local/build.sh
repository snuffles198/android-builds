#!/bin/bash

set -v

if [ $# -lt 1 ]; then
	echo 'axion calyx pixelos voltage crDroidAndroid-15 crDroidAndroid-16 crDroidAndroid-17 lineage-20 lineage-21 lineage-22 lineage-23 lineage-24 Project_Infinity-X RisingOS_Revived-8'
	exit 1
fi

export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
source /home/user/.bashrc
ccache -X 15

JJ_SPEC=$2

BUILD_DIR=/home/user/ssd1/build/android

sleep 11

case "$1" in
axion)
	REMOTE=/home/frs/project/joes-android-builds/axion/
	;;
calyx)
        rm -rf $BUILD_DIR/
        mkdir $BUILD_DIR
        cd $BUILD_DIR/ || exit 1
        ln -s /home/user/hdd1/repo.git/calyx-17/.repo . || exit 1
        curl -o calyx.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/calyx.sh || exit 1
        curl -o convert-local.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/local/convert-local.sh
        bash convert-local.sh calyx.sh
        bash calyx.sh $JJ_SPEC || exit 1
        cp *.zip /home/user/hdd1/ROMS/
        ;;
pixelos)
        rm -rf $BUILD_DIR/
        mkdir $BUILD_DIR
        cd $BUILD_DIR/ || exit 1
        ln -s /home/user/hdd1/repo.git/pixelos-17/.repo . || exit 1
        curl -o pixelos-17.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/pixelos-17.sh || exit 1
        curl -o convert-local.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/local/convert-local.sh
        bash convert-local.sh pixelos-17.sh
        bash pixelos-17.sh $JJ_SPEC || exit 1
        cp *.zip /home/user/hdd1/ROMS/
        ;;
voltage)
        rm -rf $BUILD_DIR/
        mkdir $BUILD_DIR
        cd $BUILD_DIR/ || exit 1
        ln -s /home/user/hdd1/repo.git/voltage-17/.repo . || exit 1
        curl -o voltage-6.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/voltage-6.sh || exit 1
        curl -o convert-local.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/local/convert-local.sh
        bash convert-local.sh voltage-6.sh
        bash voltage-6.sh $JJ_SPEC || exit 1
        cp *.zip /home/user/hdd1/ROMS/
	;;
crdroid-10)
	REMOTE=/home/frs/project/joes-android-builds/crDroid/10/
	;;
crDroidAndroid-15)
        rm -rf $BUILD_DIR/
        mkdir $BUILD_DIR
        cd $BUILD_DIR/ || exit 1
        ln -s /home/user/hdd1/repo.git/crDroid-11/.repo . || exit 1
        curl -o crdroid-15.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/crdroid-15.sh || exit 1
        curl -o convert-local.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/local/convert-local.sh
        bash convert-local.sh crdroid-15.sh
        bash crdroid-15.sh $JJ_SPEC || exit 1
        cp *.zip /home/user/hdd1/ROMS/
        ;;
crDroidAndroid-16)
        rm -rf $BUILD_DIR/
        mkdir $BUILD_DIR
        cd $BUILD_DIR/ || exit 1
        ln -s /home/user/hdd1/repo.git/crDroid-12/.repo . || exit 1
        curl -o crdroid-16.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/crdroid-16.sh || exit 1
        curl -o convert-local.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/local/convert-local.sh
        bash convert-local.sh crdroid-16.sh
        bash crdroid-16.sh $JJ_SPEC || exit 1
        cp *.zip /home/user/hdd1/ROMS/
        ;;
crDroidAndroid-17)
        rm -rf $BUILD_DIR/
        mkdir $BUILD_DIR
        cd $BUILD_DIR/ || exit 1
        ln -s /home/user/hdd1/repo.git/crDroid-13/.repo . || exit 1
        curl -o crdroid-17.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/crdroid-17.sh || exit 1
        curl -o convert-local.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/local/convert-local.sh
        bash convert-local.sh crdroid-17.sh
        bash crdroid-17.sh $JJ_SPEC || exit 1
        cp *.zip /home/user/hdd1/ROMS/
        ;;
lineage-20)
	REMOTE=/home/frs/project/joes-android-builds/LineageOS/20/
	;;
lineage-21)
	REMOTE=/home/frs/project/joes-android-builds/LineageOS/21/
	;;
lineage-22)
        rm -rf $BUILD_DIR/
        mkdir $BUILD_DIR
        cd $BUILD_DIR/ || exit 1
        ln -s  ~/hdd1/repo.git/lineage-22.2/.repo . || exit 1
        curl -o lineage-22.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/lineage-22.sh || exit 1
        curl -o convert-local.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/local/convert-local.sh
        bash convert-local.sh lineage-22.sh
        bash lineage-22.sh $JJ_SPEC || exit 1
        cp *.zip /home/user/hdd1/ROMS/
        ;;
lineage-23)
        rm -rf $BUILD_DIR/
        mkdir $BUILD_DIR
        cd $BUILD_DIR/ || exit 1
        ln -s  ~/hdd1/repo.git/lineage-23.2/.repo . || exit 1
        curl -o lineage-23.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/lineage-23.sh || exit 1
        curl -o convert-local.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/local/convert-local.sh
        bash convert-local.sh lineage-23.sh
        bash lineage-23.sh $JJ_SPEC || exit 1
        cp *.zip /home/user/hdd1/ROMS/
        ;;
lineage-24)
        rm -rf $BUILD_DIR/
        mkdir $BUILD_DIR
        cd $BUILD_DIR/ || exit 1
        ln -s  ~/hdd1/repo.git/lineage-24.0/.repo . || exit 1
        curl -o lineage-24.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/lineage-24.sh || exit 1
        curl -o convert-local.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/local/convert-local.sh
        bash convert-local.sh lineage-24.sh
        bash lineage-24.sh $JJ_SPEC || exit 1
        cp *.zip /home/user/hdd1/ROMS/
        ;;
Project_Infinity-X)
        rm -rf $BUILD_DIR/
        mkdir $BUILD_DIR
        cd $BUILD_DIR/ || exit 1
        ln -s  ~/hdd1/repo.git/inf-x17/.repo . || exit 1
        curl -o infinity-x-17.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/infinity-x-17.sh || exit 1
        curl -o convert-local.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/local/convert-local.sh
        bash convert-local.sh infinity-x-17.sh
        bash infinity-x-17.sh CONTINUE $JJ_SPEC || exit 1
        cp *.zip /home/user/hdd1/ROMS/
	;;
RisingOS_Revived)
        rm -rf $BUILD_DIR/
        mkdir $BUILD_DIR
        cd $BUILD_DIR/ || exit 1
        ln -s /home/user/hdd1/repo.git/rising-17/.repo . || exit 1
        curl -o rising-17.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/remote/rising-17.sh || exit 1
        curl -o convert-local.sh -L https://raw.githubusercontent.com/snuffles198/android-builds/refs/heads/main/local/convert-local.sh
        bash convert-local.sh rising-17.sh
        bash rising-17.sh CONTINUE $JJ_SPEC || exit 1
        cp *.zip /home/user/hdd1/ROMS/
        ;;
*)
        echo 'axion calyx pixelos voltage crDroidAndroid-15 crDroidAndroid-16 crDroidAndroid-17 lineage-20 lineage-21 lineage-22 lineage-23 lineage-24 Project_Infinity-X RisingOS_Revived-8'
	exit 1
	;;
esac
