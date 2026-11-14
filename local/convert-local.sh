
sed -i 's#git clone https://github.com/snuffles198/device_tree.*-b \$DEVICE_BRANCH device/xiaomi/chime \; check_fail#mkdir -p device/xiaomi/ \
cp -rf ~/hdd1/device-tree/Joe-device/ device/xiaomi/chime\
check_fail ; cd device/xiaomi/chime ; rm -rf * ; git reset --hard ; git switch $DEVICE_BRANCH ; check_fail ; git pull ; check_fail ; cd /tmp/src/android/#g' $1
sed -i 's#git clone https://github.com/snuffles198/vendor_tree.*-b \$VENDOR_BRANCH vendor/xiaomi/chime \; check_fail#mkdir -p vendor/xiaomi \
cp -rf ~/hdd1/device-tree/Joe-vendor/ vendor/xiaomi/chime\
check_fail ; cd vendor/xiaomi/chime ; rm -rf * ; git reset --hard ; git switch $VENDOR_BRANCH ; check_fail ; git pull ; check_fail ; cd /tmp/src/android/#g' $1

sed -i 's#40 \* 1024 \* 1024 \* 1024#35 * 1024 * 1024 * 1024#g' $1
