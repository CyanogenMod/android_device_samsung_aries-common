#!/tmp/busybox sh
#
# Universal Updater Script for Samsung Galaxy S Phones
# (c) 2011 by Teamhacksung
# Combined GSM & CDMA version
#

SYSTEM_SIZE='629145600' # 600M

check_mount() {
    MOUNT_POINT=`/tmp/busybox readlink -f $1`
    if ! /tmp/busybox grep -q $MOUNT_POINT /proc/mounts ; then
        /tmp/busybox mkdir -p $MOUNT_POINT
        /tmp/busybox umount -l $2
        if ! /tmp/busybox mount -t $3 $2 $MOUNT_POINT ; then
            /tmp/busybox echo "Cannot mount $1 ($MOUNT_POINT)."
            exit 1
        fi
    fi
}

set_log() {
    rm -rf $1
    exec >> $1 2>&1
}

warn_repartition() {
    if ! /tmp/busybox test -e /.accept_wipe ; then
        /tmp/busybox touch /.accept_wipe
        ui_print
        ui_print "============================================"
        ui_print "This ROM uses an incompatible partition layout"
        ui_print "Your /data will be wiped upon installation"
        ui_print "Run this update.zip again to confirm install"
        ui_print "============================================"
        ui_print
        exit 9
    fi
    /tmp/busybox rm /.accept_wipe
}

format_partitions() {
    /lvm/sbin/lvm lvcreate -L ${SYSTEM_SIZE}B -n system lvpool
    /lvm/sbin/lvm lvcreate -l 100%FREE -n userdata lvpool

    # format data (/system will be formatted by updater-script)
    /tmp/make_ext4fs -b 4096 -g 32768 -i 8192 -I 256 -l -16384 -a /data /dev/lvpool/userdata

    # unmount and format datadata
    /tmp/busybox umount -l /datadata
    /tmp/erase_image datadata
}

# ui_print by Chainfire
OUTFD=$(/tmp/busybox ps | /tmp/busybox grep -v "grep" | /tmp/busybox grep -o -E "update_binary(.*)" | /tmp/busybox cut -d " " -f 3);
ui_print() {
  if [ $OUTFD != "" ]; then
    echo "ui_print ${1} " 1>&$OUTFD;
    echo "ui_print " 1>&$OUTFD;
  else
    echo "${1}";
  fi;
}

set -x
export PATH=/:/sbin:/system/xbin:/system/bin:/tmp:$PATH

# Check if we're in CDMA or GSM mode
if /tmp/busybox test "$1" = cdma ; then
    # CDMA mode
    IS_GSM='/tmp/busybox false'
    SD_PART='/dev/block/mmcblk1p1'
    MMC_PART='/dev/block/mmcblk0p1 /dev/block/mmcblk0p2'
    MTD_SIZE='490733568'
else
    # GSM mode
    IS_GSM='/tmp/busybox true'
    SD_PART='/dev/block/mmcblk0p1'
    MMC_PART='/dev/block/mmcblk0p2'
    MTD_SIZE='442499072'
fi

# check for old/non-cwm recovery.
if ! /tmp/busybox test -n "$UPDATE_PACKAGE" ; then
    # scrape package location from /tmp/recovery.log
    UPDATE_PACKAGE=`/tmp/busybox cat /tmp/recovery.log | /tmp/busybox grep 'Update location:' | /tmp/busybox tail -n 1 | /tmp/busybox cut -d ' ' -f 3-`
fi

# check if we're running on a bml, mtd (old) or mtd (current) device
if /tmp/busybox test -e /dev/block/bml7 ; then
    # we're running on a bml device

    # make sure sdcard is mounted
    check_mount /mnt/sdcard $SD_PART vfat

    # everything is logged into /mnt/sdcard/cyanogenmod_bml.log
    set_log /mnt/sdcard/cyanogenmod_bml.log

    if $IS_GSM ; then
        # make sure efs is mounted
        check_mount /efs /dev/block/stl3 rfs

        # create a backup of efs
        if /tmp/busybox test -e /mnt/sdcard/backup/efs ; then
            /tmp/busybox mv /mnt/sdcard/backup/efs /mnt/sdcard/backup/efs-$$
        fi
        /tmp/busybox rm -rf /mnt/sdcard/backup/efs

        /tmp/busybox mkdir -p /mnt/sdcard/backup/efs
        /tmp/busybox cp -R /efs/ /mnt/sdcard/backup
    fi

    # write the package path to sdcard cyanogenmod.cfg
    if /tmp/busybox test -n "$UPDATE_PACKAGE" ; then
        PACKAGE_LOCATION=${UPDATE_PACKAGE#/mnt}
        /tmp/busybox echo "$PACKAGE_LOCATION" > /mnt/sdcard/cyanogenmod.cfg
    fi

    # Scorch any ROM Manager settings to require the user to reflash recovery
    /tmp/busybox rm -f /mnt/sdcard/clockworkmod/.settings

    # write new kernel to boot partition
    /tmp/flash_image boot /tmp/boot.img
    if [ "$?" != "0" ] ; then
        exit 3
    fi
    /tmp/busybox sync

    /sbin/reboot now
    exit 0

elif /tmp/busybox test `/tmp/busybox cat /sys/class/mtd/mtd2/size` != "$MTD_SIZE" || \
    /tmp/busybox test `/tmp/busybox cat /sys/class/mtd/mtd2/name` != "datadata" ; then
    # we're running on a mtd (old) device

    # make sure sdcard is mounted
    check_mount /sdcard $SD_PART vfat

    # everything is logged into /sdcard/cyanogenmod_mtd_old.log
    set_log /sdcard/cyanogenmod_mtd_old.log

    warn_repartition

    # write the package path to sdcard cyanogenmod.cfg
    if /tmp/busybox test -n "$UPDATE_PACKAGE" ; then
        /tmp/busybox echo "$UPDATE_PACKAGE" > /sdcard/cyanogenmod.cfg
    fi

    # inform the script that this is an old mtd upgrade
    /tmp/busybox echo 1 > /sdcard/cyanogenmod.mtdupd

    # clear datadata
    /tmp/busybox umount -l /datadata
    /tmp/erase_image datadata

    # write new kernel to boot partition
    /tmp/bml_over_mtd.sh boot 72 reservoir 2004 /tmp/boot.img

	# Remove /system/build.prop to trigger emergency boot
	/tmp/busybox mount /system
	/tmp/busybox rm -f /system/build.prop
	/tmp/busybox umount -l /system

    /tmp/busybox sync

    /sbin/reboot now
    exit 0

elif /tmp/busybox test -e /dev/block/mtdblock0 ; then
    # we're running on a mtd (current) device

    # make sure sdcard is mounted
    check_mount /sdcard $SD_PART vfat

    # everything is logged into /sdcard/cyanogenmod.log
    set_log /sdcard/cyanogenmod_mtd.log

    # unmount system and data (recovery seems to expect system to be unmounted)
    /tmp/busybox umount -l /system
    /tmp/busybox umount -l /data

    # Resize partitions
    # (For first install, this will get skipped because device doesn't exist)
    if /tmp/busybox test `/tmp/busybox blockdev --getsize64 /dev/mapper/lvpool-system` -lt $SYSTEM_SIZE ; then
        warn_repartition
        /lvm/sbin/lvm lvremove -f lvpool
        format_partitions
    fi

    if $IS_GSM ; then
        # create mountpoint for radio partition
        /tmp/busybox mkdir -p /radio

        # make sure radio partition is mounted
        if ! /tmp/busybox grep -q /radio /proc/mounts ; then
            /tmp/busybox umount -l /dev/block/mtdblock5
            if ! /tmp/busybox mount -t yaffs2 /dev/block/mtdblock5 /radio ; then
                /tmp/busybox echo "Cannot mount radio partition."
                exit 5
            fi
        fi

        # if modem.bin doesn't exist on radio partition, format the partition and copy it
        if ! /tmp/busybox test -e /radio/modem.bin ; then
            /tmp/busybox umount -l /dev/block/mtdblock5
            /tmp/erase_image radio
            if ! /tmp/busybox mount -t yaffs2 /dev/block/mtdblock5 /radio ; then
                /tmp/busybox echo "Cannot copy modem.bin to radio partition."
                exit 5
            else
                /tmp/busybox cp /tmp/modem.bin /radio/modem.bin
            fi
        fi

        # unmount radio partition
        /tmp/busybox umount -l /dev/block/mtdblock5
    fi

    if ! /tmp/busybox test -e /sdcard/cyanogenmod.cfg ; then
        # update install - flash boot image then skip back to updater-script
        # (boot image is already flashed for first time install or old mtd upgrade)

        # flash boot image
        /tmp/bml_over_mtd.sh boot 72 reservoir 2004 /tmp/boot.img

        if ! $IS_GSM ; then
            /tmp/bml_over_mtd.sh recovery 102 reservoir 2004 /tmp/recovery_kernel
        fi

        exit 0
    fi

    # if a cyanogenmod.cfg exists, then this is a first time install
    # let's format the volumes and restore radio and efs

    # remove the cyanogenmod.cfg to prevent this from looping
    /tmp/busybox rm -f /sdcard/cyanogenmod.cfg

    # setup lvm volumes
    /lvm/sbin/lvm pvcreate $MMC_PART
    /lvm/sbin/lvm vgcreate lvpool $MMC_PART
    format_partitions

    # restart into recovery so the user can install further packages before booting
    /tmp/busybox touch /cache/.startrecovery

    if /tmp/busybox test -e /sdcard/cyanogenmod.mtdupd ; then
        # this is an upgrade with changed MTD mapping for /data, /cache, /system
        # so return to updater-script after formatting them

        /tmp/busybox rm -f /sdcard/cyanogenmod.mtdupd

        exit 0
    fi

    if $IS_GSM ; then
        # restore efs backup
        if /tmp/busybox test -e /sdcard/backup/efs/nv_data.bin || \
                /tmp/busybox test -e /sdcard/backup/efs/root/afs/settings/nv_data.bin ; then
            /tmp/busybox umount -l /efs
            /tmp/erase_image efs
            /tmp/busybox mkdir -p /efs

            if ! /tmp/busybox grep -q /efs /proc/mounts ; then
                if ! /tmp/busybox mount -t yaffs2 /dev/block/mtdblock4 /efs ; then
                    /tmp/busybox echo "Cannot mount efs."
                    exit 6
                fi
            fi

            /tmp/busybox cp -R /sdcard/backup/efs /
            /tmp/busybox umount -l /efs
        else
            /tmp/busybox echo "Cannot restore efs."
            exit 7
        fi
    fi

    exit 0
fi

