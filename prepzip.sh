#!/usr/bin/env bash

set -eu -o pipefail
 
# Requires bootimg tools and p7zip in path
# Exec from kernel dir 

[[ ${1-} == '--debug' ]] && set -x && shift

kern_cmdline='console=ttyS1,115200n8 androidboot.selinux=permissive' 
kern_base='0x00000000'
kern_pagesize='2048' 
kern_ramdisk_dir='build/ramdisk/mint2g_ramdisk'

kern_image='arch/arm/boot/Image'
zip_type='normal'

[[ -z "${TIMEZONE-}" ]] && TIMEZONE="UTC"
build_date="$( TZ="$TIMEZONE" date '+%Y-%m-%d-%H%M' )"

is_archived=0
for i in "build/archive/"* ; do
if cmp "$i" "$kern_image" &> /dev/null ; then
is_archived=1
break;
fi;
done

if [[ $is_archived == 0 ]]; then
echo "Archiving kernel image"
cp $kern_image "build/archive/Image.${build_date}"
fi;


tmp_dir="$(mktemp -d )"
mkdir "$tmp_dir/boot"
mkdir "$tmp_dir/modules"

pushd "$kern_ramdisk_dir"  &> /dev/null

kern_ramdisk="$tmp_dir/boot/newramdisk.cpio.gz"

echo "Creating ramdisk,. "
find  .  -mindepth 1 -not \(  -path './.git' -prune  \)  | cpio -o -H newc | gzip > "$kern_ramdisk"

popd &> /dev/null

echo "Preparing boot image"
     mkbootimg --kernel "$kern_image" --ramdisk "$kern_ramdisk" \
     --cmdline "$kern_cmdline" --base "$kern_base" --pagesize "$kern_pagesize" \
     -o "$tmp_dir/boot/boot.img" 


echo


echo "Copying new modules"

# Excludes some dirs
find . -not \( -path ./Documentation -prune \)  -not \( -path ./include -prune \) -not \( -path ./Kbuild -prune \) -name \*.ko -exec  cp '{}' "$tmp_dir/modules/" \;

echo "Stripping modules"
find "$tmp_dir/modules" -type f -exec \
objcopy --strip-unneeded {} \;

echo "Preparing flashable zip"
zip_outname="cm11-kernel-${build_date}.zip" 

case $zip_type in
'autobackup')
mkdir "$tmp_dir/compressed_data"

mv  "$tmp_dir/boot/boot.img" "$tmp_dir/compressed_data/boot.img"
mv  "$tmp_dir/modules" "$tmp_dir/compressed_data/modules" 

( cd "$tmp_dir/compressed_data" &&  7z a "../data.7z"  ./* )

build/zip_autobackup/join4zip.py "$tmp_dir/join4zip" 

mv "$tmp_dir/data.7z" "$tmp_dir/join4zip"

( cd "$tmp_dir/join4zip" &&  7z a "../$zip_outname"  ./* )
;;
'normal')

build/zip_normal/join4zip.py "$tmp_dir/join4zip" 

mv  "$tmp_dir/boot/boot.img" "$tmp_dir/join4zip/boot.img"
mv  "$tmp_dir/modules" "$tmp_dir/join4zip/modules" 

( cd "$tmp_dir/join4zip" &&  7z a "../$zip_outname"  ./* )
;;
esac


cp "$tmp_dir/$zip_outname" build/out 
