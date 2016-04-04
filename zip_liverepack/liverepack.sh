#!/sbin/busybox sh

set -x

# log to temp dir
exec >> "/tmp/liverepack.log" 2<&1

# configs, but this no general
BLK_SYSTEM='/dev/block/mmcblk0p21'
BLK_KERNEL='/dev/block/mmcblk0p5'

# globals
XTRCT_DIR='/tmp/xtracted'
WORK_DIR='/tmp/liverepack'

# log trap
copylog_on_pre_exit() {
SD_PATH="/data/media/0"
ui_print "copying log to $SD_PATH/liverepack.log"
rm "$SD_PATH/liverepack.log"
cp "/tmp/liverepack.log" "$SD_PATH/liverepack.log"
}

trap copylog_on_pre_exit EXIT

# ui_print
OUTFD=$(\
    /tmp/busybox ps | \
    /tmp/busybox grep -v "grep" | \
    /tmp/busybox grep -o -E "/tmp/updater .*" | \
    /tmp/busybox cut -d " " -f 3\
);

if /tmp/busybox test -e /tmp/update_binary ; then
    OUTFD=$(\
        /tmp/busybox ps | \
        /tmp/busybox grep -v "grep" | \
        /tmp/busybox grep -o -E "update_binary(.*)" | \
        /tmp/busybox cut -d " " -f 3\
    );
fi

ui_print() {
    if [ "${OUTFD}" != "" ]; then
        echo "ui_print ${1} " 1>&"${OUTFD}";
        echo "ui_print " 1>&"${OUTFD}";
    else
        echo "${1}";
    fi
}

system_mount_check_rom() {
# mount system and see rom is installed.
if [ ! -e /system/build.prop ]; then
# screw old recoveries
/tmp/busybox mount "$BLK_SYSTEM" /system
fi;
if [ ! -e /system/build.prop ]; then
ui_print "You should install a rom first flashing this kernel."
exit;
fi;
}

getAndroidSDKVersion() {
# parse from build.prop
/tmp/busybox grep ro.build.version.sdk /system/build.prop | /tmp/busybox awk -F '=' '{print $2}'
}

setup_workspace() {
/tmp/busybox rm -rf "$WORK_DIR"
/tmp/busybox mkdir "$WORK_DIR"
if [ ! -d "$XTRCT_DIR" ]; then
ui_print  "FATAL: Nothing to repack"
exit 8
fi
/tmp/busybox cp "$XTRCT_DIR/kernel" "$WORK_DIR/kernel"
api="$(getAndroidSDKVersion)"
rdisk="${XTRCT_DIR}/ramdisks/ramdisk-${api}.cpio.gz"
if [ ! -e "$rdisk" ]; then
ui_print "Unsupported ROM."
exit
fi
/tmp/busybox  cp "$rdisk" "$WORK_DIR/ramdisk.cpio.gz"
}

repack_bootimg() {
# hard coded
/tmp/mkbootimg --base 0 --pagesize 2048 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --second_offset 0x00f00000 --tags_offset 0x00000100 --cmdline 'crappy samsung bootloader' --kernel "$WORK_DIR/kernel" --ramdisk "$WORK_DIR/ramdisk.cpio.gz" -o "$WORK_DIR/boot.img" 
if [ ! -e "$WORK_DIR/boot.img" ]; then
ui_print "FATAL: couldnt pack boot.img" 
exit 5
fi;
}

call_preflash() { 
"$XTRCT_DIR/hooks/preflash.sh" "${api}"
}


call_postflash() {
"$XTRCT_DIR/hooks/postflash.sh" "${api}"
}

flash_kernel() {
/tmp/busybox true
# raw write for now
/tmp/busybox dd if="$WORK_DIR/boot.img" of="$BLK_KERNEL"
echo "raw_write: ret=$?"
}


cleanup() {
/tmp/busybox true
# 
# umount /system
# /tmp/busybox rm -rf "$WORK_DIR"
# /tmp/busybox rm -rf "$XTRCT_DIR"
}

 
system_mount_check_rom
setup_workspace
repack_bootimg
#call_preflash
flash_kernel
#call_postflash
cleanup

# uncomment for testing
# exit 11

