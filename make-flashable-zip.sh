#!/bin/bash

#   creating: data/
#  inflating: data/system.img
#  inflating: data/rootfs.img
#   creating: META-INF/
#   creating: META-INF/com/
#   creating: META-INF/com/google/
#   creating: META-INF/com/google/android/
#  inflating: META-INF/com/google/android/update-binary
# extracting: META-INF/com/google/android/updater-script
#   creating: tools/
#  inflating: tools/busybox
#  inflating: ubports.sh

home=`pwd`
rm -rf buildzip
cp ziptemplate buildzip -r
cd buildzip
cd data
cp "$home/../target/target-rootfs.img" rootfs.img
cp "$home/../target/target-system.img" system.img
cd ..
zip ../../target/target.zip * -r
