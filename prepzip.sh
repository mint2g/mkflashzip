#!/usr/bin/env bash

set -eu -o pipefail

# Requires bootimgtools, mkbootfs and p7zip in path
# Should be in kernel_dir/build
# Exec from kernel_dir
# TODO: implement default zip as debug unless -r <version> is specified

[[ ${1-} == '--debug' ]] && set -x && shift

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRITPT_CONFIG="$SCRIPT_DIR/config.prepzip"

if [[ ! -f "$SCRITPT_CONFIG" ]]; then
echo "No config file found exiting"
exit -1
fi;

. "$SCRITPT_CONFIG"



[[ ! -e 'build/prepzip.sh' ]] && echo "Script should be called from the kernel dir." && exit 1


[[ -z "${TIMEZONE-}" ]] && TIMEZONE="UTC"
packaged_date="$( TZ="$TIMEZONE" date '+%Y-%m-%d-%H%M' )"


archive_kernel_image() {
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
}

setup_workspace() {
tmp_dir="$(mktemp -d )"
echo "Build started in $tmp_dir"
mkdir "$tmp_dir/boot"
mkdir "$tmp_dir/modules"
}


generate_ramdisk() {
# generate_ramdisk <src-dir> <out-path>

local out_name
out_name="$(basename "$2")"
gend_suff="${out_name#ramdisk}"
gend_suff="${gend_suff%.cpio.gz*}"

local gen_dir="$tmp_dir/boot/genramdisk${gend_suff-}"
mkdir "$gen_dir"

echo "Generating ramdisk: $out_name ... " 
tar -cpC "./$1" \
'--exclude=.git' '--exclude=.gendirs' './' \
| tar -xpC "$gen_dir"

while IFS='' read -r line || [[ -n "$line" ]]; do
[[ ! -d "$gen_dir/${line}" ]] && mkdir "$gen_dir/${line}"
done < "$1/.gendirs"

mkbootfs "$gen_dir" | gzip  > "$2"
}


make_bootimg_with_ramdisk() {
# make_bootimg <ramdisk> <out>
echo "Preparing boot image"
     mkbootimg \
     --kernel "$BOOTIMG_KERNEL" \
     --ramdisk "$1" \
     --cmdline "${BOOTIMG_ARGS[0]}" \
     --base "${BOOTIMG_ARGS[1]}" \
     --pagesize "${BOOTIMG_ARGS[2]}" \
     -o "$2"
}


prepare_modules() {
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
}

save_zip_to_out() {
if [[ ! -e $tmp_dir/$ZIP_OUT_FILE ]]; then
echo "FATAL: zip creation failed"
exit 4;
fi
cp "$tmp_dir/$ZIP_OUT_FILE" "build/out/$ZIP_OUT_FILE"
}


## main
ZIP_OUT_FILE="${ZIP_OUT_STR}-${packaged_date}.zip"
setup_workspace

case $ZIP_TYPE in

'autobackup')
# FIXME: broken will fix later
echo "Preparing autobackup flashable zip"
  mkdir "$tmp_dir/compressed_data"

  mv  "$tmp_dir/boot/boot.img" "$tmp_dir/compressed_data/boot.img"
  mv  "$tmp_dir/modules" "$tmp_dir/compressed_data/modules"

  ( cd "$tmp_dir/compressed_data" &&  7z a "../data.7z"  ./* )
  build/zip_autobackup/join4zip.py "$tmp_dir/join4zip"

  mv "$tmp_dir/data.7z" "$tmp_dir/join4zip"

  ( cd "$tmp_dir/join4zip" &&  7z a "../$ZIP_OUT_FILE"  ./* )

;;

'normal') 
if [[ -z "$BOOTIMG_NORMAL_PREBUILT_RAMDISK" ]]; then
  BOOTIMG_NORMAL_RAMDISK="$tmp_dir/boot/ramdisk.cpio.gz"
  generate_ramdisk "$BOOTIMG_NORMAL_RAMDISK_DIR"  "$BOOTIMG_NORMAL_RAMDISK"
else 
  BOOTIMG_NORMAL_RAMDISK="$BOOTIMG_NORMAL_PREBUILT_RAMDISK"
fi
make_bootimg_with_ramdisk "$BOOTIMG_NORMAL_RAMDISK" "$tmp_dir/boot/boot.img"
prepare_modules

# FIXME: change join4zip.py to preparezip.py for handling zip creation 
echo "Preparing normal  flashable zip"
  build/zip_normal/join4zip.py "$tmp_dir/join4zip"
  mv  "$tmp_dir/boot/boot.img" "$tmp_dir/join4zip/boot.img"
  mv  "$tmp_dir/modules" "$tmp_dir/join4zip/modules"
  ( cd "$tmp_dir/join4zip" &&  7z a "../$ZIP_OUT_FILE"  ./* )
;;

'liverepack')

for rd_str in "${BOOTIMG_LIVEREPACK_RAMDISKS_DIRS[@]}"  ; do
rd_api=${rd_str%|*}
rd_dir=${rd_str#*|}
generate_ramdisk "$rd_dir" "$tmp_dir/boot/ramdisk-${rd_api}.cpio.gz" 
done

prepare_modules
echo "Preparing normal  flashable zip"
 build/zip_liverepack/join4zip.py "$tmp_dir/join4zip" 
mkdir -p "$tmp_dir/join4zip/files/ramdisks"
find "$tmp_dir/boot" -name "*.cpio.gz" -exec mv '{}'  "$tmp_dir/join4zip/files/ramdisks" ';'
cp "$BOOTIMG_KERNEL" "$tmp_dir/join4zip/files/kernel"
mv  "$tmp_dir/modules" "$tmp_dir/join4zip/" 
( cd "$tmp_dir/join4zip" &&  7z a "../$ZIP_OUT_FILE"  ./* )
;;
esac

# copy the zip file to disk from tempdir
save_zip_to_out
