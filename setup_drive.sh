#!/bin/bash
SECONDS=0

showUsage() {
	echo "Usage: $(basename $0) <sourcePath> <deviceTarget> [F]"
}

showElapsed() {
	duration=$SECONDS
	printf "$(($duration / 60))' $(($duration % 60))\"\n"
}

if [ $EUID -ne 0 ]; then
    echo "Please run as root"
    exit
fi

if [ $# -lt 2 ]; then
	showUsage
	exit 1
fi

FORMAT="no"
if [ $# -eq 3 ]; then
	if [ "$3" != 'F' ]; then
		showUsage
		exit 1
	fi

	FORMAT="yes"
fi

SOURCE_BOOT="$1/0.fat"
SOURCE_SYS="$1/1.img"
TARGET_DRIVE="/dev/$2"
TARGET_BOOT="/dev/"$2"1"
TARGET_SYS="/dev/"$2"2"

if [ ! -f $SOURCE_BOOT ]; then
	echo "$SOURCE_BOOT does'nt exists"
	exit 1
fi

if [ ! -f $SOURCE_SYS ]; then
	echo "$SOURCE_SYS does'nt exists"
	exit 1
fi

if [ ! -e $TARGET_BOOT ]; then
	echo "$TARGET_BOOT does'nt exists"
	exit 1
fi

if [ ! -e $TARGET_SYS ]; then
	echo "$TARGET_SYS does'nt exists"
	exit 1
fi

PTUUID=$(blkid -o value -s PTUUID $TARGET_DRIVE)
if [ $FORMAT = 'yes' ]; then
	mkfs.vfat $TARGET_BOOT
	mkfs.ext4 $TARGET_SYS -F
fi

mkdir /boot/source /boot/target

mount -o loop $SOURCE_BOOT /boot/source
printf "Flashing $TARGET_BOOT partition ... "
mount $TARGET_BOOT /boot/target
rsync -a /boot/source/ /boot/target --delete
sed -i -- "s/e8af6eb2/$PTUUID/g" /boot/target/cmdline.txt
sed -i -- "s/ init=\/usr\/lib\/raspi-config\/init_resize.sh//g" /boot/target/cmdline.txt
touch /boot/target/ssh
showElapsed

if [ -d "$(basename $0)_Scripts" ]; then
	printf "Transfer scripts on $TARGET_BOOT .. "
	rsync -r ./"$(basename $0)_Scripts"/* /boot/target --delete
	showElapsed
fi

umount /boot/target
umount /boot/source

printf "Flashing $TARGET_SYS partition ... "
mount -o loop $SOURCE_SYS /boot/source
mount $TARGET_SYS /boot/target
rsync -a /boot/source/ /boot/target --delete
sed -i -- "s/e8af6eb2/$PTUUID/g" /boot/target/etc/fstab


umount /boot/target
showElapsed

umount /boot/source

rmdir /boot/source /boot/target
echo "Eject $TARGET_DRIVE before use"
