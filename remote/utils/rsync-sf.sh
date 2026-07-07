
if [ $# -ne 2 ]; then 
    echo 'need two args'
    echo 'axion calyx pixelos voltage crdroid-10 crdroid-11 crdroid-12 lineage-20 lineage-21 lineage-22 lineage-23 infinity'
    echo 'rom filename'
    exit 1
fi

case "$1" in
	axion)
		REMOTE=/home/frs/project/joes-android-builds/axion/
		;;
	calyx)
		REMOTE=/home/frs/project/joes-android-builds/calyxOS/
		;;
	pixelos)
		REMOTE=/home/frs/project/joes-android-builds/pixelos/
		;;
	voltage)
		REMOTE=/home/frs/project/joes-android-builds/voltage/
		;;
	crdroid-10)
		REMOTE=/home/frs/project/joes-android-builds/crDroid/10/
		;;
	crdroid-11)
		REMOTE=/home/frs/project/joes-android-builds/crDroid/11/
		;;
	crdroid-12)
		REMOTE=/home/frs/project/joes-android-builds/crDroid/12/
		;;
        lineage-20)
                REMOTE=/home/frs/project/joes-android-builds/LineageOS/20/
		;;
	lineage-21)
		REMOTE=/home/frs/project/joes-android-builds/LineageOS/21/
		;;
	lineage-22)
                REMOTE=/home/frs/project/joes-android-builds/LineageOS/22/
		;;
	lineage-23)
                REMOTE=/home/frs/project/joes-android-builds/LineageOS/23/
		;;
	infinity)
		REMOTE=/home/frs/project/joes-android-builds/Infinity-X/3/
		;;
	*)
		echo 'need two args'
	 	echo 'axion calyx pixelos voltage crdroid-10 crdroid-11 crdroid-12 lineage-20 lineage-21 lineage-22 lineage-23 infinity'
    		echo 'rom filename'
		exit 1
esac

if echo "$(hostname)" |grep devuan; then
    BWLIMIT="--bwlimit=800K"
    SSHKEY=/home/user/.ssh/sourceforge
else
    SSHKEY=sf
fi

echo $1 $2 $REMOTE
exit


while ! rsync -avz --progress --partial --inplace --timeout=60 --bwlimit=800K  -e "ssh -i /home/user/.ssh/sourceforge" $2 joe75001@frs.sourceforge.net:$REMOTE; do
    echo "Connection dropped. Retrying in 5 seconds..."
    sleep 5
done
