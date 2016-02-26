#!/usr/bin/env bash

set -eu -o pipefail

# Requires bootimgtools, mkbootfs and p7zip in path
# Should be in kernel_dir/build
# Exec from kernel_dir
# TODO: default zip is debug unless -r <version> is specified

[[ ${1-} == '--debug' ]] && set -x && shift

# config
# FIXME: config should probably be in a seperate file
USE_ARCHIVED_RAMDISK=0
ZIP_TYPE='normal'
ZIP_OUT_STR='kernel-mint2g-cm11-highly-exp-'

BOOTIMG_KERNEL='arch/arm/boot/Image'
BOOTIMG_RAMDISK_DIR='build/ramdisk/mint2g_ramdisk'
BOOTIMG_RAMDISK_ARCHIVE='build/ramdisk/ramdisk.cpio.gz'

# canned values for
# 0->cmdline, 1->base, 2->pagesize
# TODO: Use something for parsing
BOOTIMG_ARGS=(
  'crappy samsung bootloader'
  '0x00000000'
  '2048'
)

#end config



[[ ! -e 'build/prepzip.sh' ]] && echo "Script called from the wrong dir." && exit -1


[[ -z "${TIMEZONE-}" ]] && TIMEZONE="UTC"
packaged_date="$( TZ="$TIMEZONE" date '+%Y-%m-%d-%H%M' )"



# Archive the kernel image
# TODO: check if dir exisits
is_archived=0
for i in "build/archive/"* ; do
if cmp "$i" "$BOOTIMG_KERNEL" &> /dev/null ; then
is_archived=1
break;
fi;
done

if [[ $is_archived == 0 ]]; then
echo "Archiving kernel image"
cp "$BOOTIMG_KERNEL" "build/archive/Image.${packaged_date}"
fi;


tmp_dir="$(mktemp -d )"
mkdir "$tmp_dir/boot"
mkdir "$tmp_dir/boot/genramdisk"
mkdir "$tmp_dir/modules"

if [[ ${USE_ARCHIVED_RAMDISK-} != 1 ]];then
echo "Generating ramdisk,. "

tar -cpC "./$BOOTIMG_RAMDISK_DIR" \
'--exclude=.git' '--exclude=.gendirs' './' \
| tar -xpC "$tmp_dir/boot/genramdisk"

while IFS='' read -r line || [[ -n "$line" ]]; do
[[ ! -d "$tmp_dir/boot/genramdisk/${line}" ]] && mkdir "$tmp_dir/boot/genramdisk/${line}"
done < "$BOOTIMG_RAMDISK_DIR/.gendirs"

BOOTIMG_RAMDISK="$tmp_dir/boot/ramdisk.cpio.gz"

mkbootfs "$tmp_dir/boot/genramdisk" | gzip  > "$BOOTIMG_RAMDISK"

else
BOOTIMG_RAMDISK="$BOOTIMG_RAMDISK_ARCHIVE"
fi

echo "Preparing boot image"
     mkbootimg \
     --kernel "$BOOTIMG_KERNEL" \
     --ramdisk "$BOOTIMG_RAMDISK" \
     --cmdline "${BOOTIMG_ARGS[0]}" \
     --base "${BOOTIMG_ARGS[1]}" \
     --pagesize "${BOOTIMG_ARGS[2]}" \
     -o "$tmp_dir/boot/boot.img"

echo


echo "Copying new modules"

# Excludes some dirs
find . \
  -not \( -path ./Documentation -prune \) \
  -not \( -path ./include -prune \) \
  -not \( -path ./Kbuild -prune \) \
  -name \*.ko \
  -exec  cp '{}' "$tmp_dir/modules/" ';'

echo "Stripping modules"
find "$tmp_dir/modules" -type f -exec \
"${CROSS_COMPILE-}objcopy" --strip-unneeded '{}' ';'

echo "Preparing flashable zip"
ZIP_OUT_FILE="${ZIP_OUT_STR}-${packaged_date}.zip"

case $ZIP_TYPE in

'autobackup')
  mkdir "$tmp_dir/compressed_data"

  mv  "$tmp_dir/boot/boot.img" "$tmp_dir/compressed_data/boot.img"
  mv  "$tmp_dir/modules" "$tmp_dir/compressed_data/modules"

  ( cd "$tmp_dir/compressed_data" &&  7z a "../data.7z"  ./* )
  build/zip_autobackup/join4zip.py "$tmp_dir/join4zip"

  mv "$tmp_dir/data.7z" "$tmp_dir/join4zip"

  ( cd "$tmp_dir/join4zip" &&  7z a "../$ZIP_OUT_FILE"  ./* )
;;

'normal')

  build/zip_normal/join4zip.py "$tmp_dir/join4zip"

  mv  "$tmp_dir/boot/boot.img" "$tmp_dir/join4zip/boot.img"
  mv  "$tmp_dir/modules" "$tmp_dir/join4zip/modules"

  ( cd "$tmp_dir/join4zip" &&  7z a "../$ZIP_OUT_FILE"  ./* )
;;
esac


cp "$tmp_dir/$ZIP_OUT_FILE" build/out
