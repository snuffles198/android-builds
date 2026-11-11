
sed -i 's#git clone https://github.com/snuffles198/device_tree --depth=1 -b \$DEVICE_BRANCH device/xiaomi/chime \; check_fail#cp ~/hdd1/device-tree/Joe-device/ device/xiaomi/chime\
check_fail ; cd device/xiaomi/chime ; rm -rf * ; git reset --hard ; git switch $DEVICE_BRANCH ; check_fail ; git pull ; check_fail ; cd /tmp/src/android/#g' $1
sed -i 's#git clone https://github.com/snuffles198/vendor_tree --depth=1 -b \$VENDOR_BRANCH vendor/xiaomi/chime \; check_fail#cp ~/hdd1/device-tree/Joe-vendor/ vendor/xiaomi/chime\
check_fail ; cd vendor/xiaomi/chime ; rm -rf * ; git reset --hard ; git switch $VENDOR_BRANCH ; check_fail ; git pull ; check_fail ; cd /tmp/src/android/#g' $1

sed -i 's#40 \* 1024 \* 1024 \* 1024#35 * 1024 * 1024 * 1024#g' $1
