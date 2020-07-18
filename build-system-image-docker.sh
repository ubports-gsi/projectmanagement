#!/bin/bash
RUN_FROM="/opt/"
cd $RUN_FROM # Just in case somebody have not changed directory.

echo "Started script on `date`";

#echo "============="
#echo "Installing tools"
#apt update
#apt install git -y
#dpkg --add-architecture i386
#apt update
#apt install git gnupg flex bison gperf build-essential \
#  zip bzr curl libc6-dev libncurses5-dev:i386 x11proto-core-dev \
#  libx11-dev:i386 libreadline6-dev:i386 libgl1-mesa-glx:i386 \
#  libgl1-mesa-dev g++-multilib mingw-w64-i686-dev tofrodos \
#  python-markdown libxml2-utils xsltproc zlib1g-dev:i386 schedtool \
#  repo liblz4-tool bc lzop imagemagick libncurses5 rsync wget -y
#wget https://storage.googleapis.com/git-repo-downloads/repo -O /bin/repo
#chmod +x /bin/repo
#apt install docker docker.io -y
echo "============="
#echo "[+] Building rootfs."
#if [[ ! -d "/opt/tools/rootfs-builder-debos-android9" ]];
#then
#    # Directory doesn't exist, we will clone repo now.
#    echo "[+] Cloning repo"
#    git clone https://github.com/MrCyjaneK/rootfs-builder-debos-android9 /opt/tools/rootfs-builder-debos-android9
#else
#    echo "[+] Pulling repo"
#    cd "/opt/tools/rootfs-builder-debos-android9"
#    git pull
#fi
#echo "[+] Starting docker..."
#dockerd &
#sleep 10
#cd /opt/tools/rootfs-builder-debos-android9
#echo "[+] Running debos"
#docker run --rm --interactive --tty --device /dev/kvm --user $(id -u) --group-add kvm --workdir /recipes --mount "type=bind,source=$(pwd),destination=/recipes" --security-opt label=disable godebos/debos -m 4G android9-generic.yaml
#echo "[+] Killing docker"
#killall docker

echo "[+] Building halium GSI"

if [[ ! -d "/opt/tools/Halium-9.0" ]];
then
    mkdir -p /opt/tools/Halium-9.0
    cd /opt/tools/Halium-9.0
    # Directory doesn't exist, we will clone repo now.
    echo "    [+] Cloning repo"
    repo init -u https://github.com/Halium/android -b halium-9.0 --depth=1
    repo sync -c -j16 -v
else
    cd /opt/tools/Halium-9.0
    echo "     [+] Removing current repo"
    rm -rf *
    #echo "    [+] Pulling repo"
    repo sync -c -j16 -v -l
fi

echo "[+] Building rootfs"

export CCACHE_DIR=/data/build/.ccache
export USE_CCACHE=1
#export PATH=/var/lib/jenkins/bin:$PATH
export LANG=C

DEVICE=ubport
ROOTDIR="/opt/tools/Halium-9.0"
JAVA=/usr/lib/jvm/jdk-11.0.7/

if [ -z $DEVICE ]; then
    echo DEVICE not set
    exit 1
fi

if [ -z $ROOTDIR ]; then
    echo ROOTDIR not set
    exit 1
fi

if [ -z $JAVA ]; then
    export JAVA_HOME=/usr/lib/jvm/jdk-11.0.7/
else
    export JAVA_HOME=$JAVA
fi

#export JACK_SERVER_VM_ARGUMENTS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4096m"

echo USER=$USER
echo DEVICE=$DEVICE
echo CCACHE_DIR=$CCACHE_DIR
echo ROOTDIR=$ROOTDIR
echo JAVA_HOME=$JAVA_HOME
export LC_ALL=C
#export ALLOW_MISSING_DEPENDENCIES=true
#export DTC_EXT=dtc

#ccache -M 40G
ccache -s

cd $ROOTDIR

#rm .repo/local_manifests/roomservice.xml

#repo sync --force-sync -cdf -j8 --no-clone-bundle --no-tags

if [ -d device/halium/ubport ]; then
    cd device/halium/ubport
    git fetch origin
    git reset --hard origin/halium-9.0
    cd ../../..
else
    git clone https://github.com/ubports-gsi/android_device_halium_ubport -b halium-9.0 device/halium/ubport
fi

#TODO: Would be nice to not clone it everytime...
#rm -rf external/libhybris
#git clone https://github.com/erfanoabdi/libhybris/ external/libhybris

#rm -rf tools/metalava
#git clone https://android.googlesource.com/platform/tools/metalava tools/metalava/

#if [ -d external/libhybris ]; then
#    cd external/libhybris
#    git fetch erfan
#    git reset --hard erfan/master
#    cd ../..
#fi

if [ -d platform-api ]; then
    cd platform-api
    git fetch origin
    git reset --hard origin/xenial
    cd ..
fi

#if [ -d biometryd ]; then
#    cd biometryd
#    git fetch origin
#    git reset --hard origin/xenial
#    cd ..
#else
#    git clone https://github.com/erfanoabdi/biometryd -b xenial biometryd
#fi

if [ -d vendor/vndk ]; then
    cd vendor/vndk
    git pull
    cd ../..
else
    git clone https://github.com/ubports-gsi/vendor_vndk vendor/vndk
fi

if [ -d prebuilts/vndk/v27 ]; then
    cd prebuilts/vndk/v27
    cd ../../..
else
    git clone https://android.googlesource.com/platform/prebuilts/vndk/v27 prebuilts/vndk/v27 -b pie-qpr3-release
fi

if [ -d hfd-service ]; then
    cd hfd-service
    git fetch origin
    git reset --hard origin/xenial_-_edge_-_android8
    cd ..
else
    git clone https://github.com/ubports-gsi/hfd-service -b xenial_-_edge_-_android8 hfd-service
fi

echo '[+] Make cleaning...'
#make installclean -j8
rm -rf $ROOTDIR/out/target/product/$DEVICE/lineage-*.zip
rm -rf $ROOTDIR/out/target/product/$DEVICE/system.img
rm -rf $ROOTDIR/out/target/product/$DEVICE/hybris-boot.img
rm -rf $ROOTDIR/out/target/product/$DEVICE/vendor.img
rm -rf $ROOTDIR/out/target/product/$DEVICE/dtbo.img

echo '[+] Lunching...'
. /opt/tools/Halium-9.0/build/envsetup.sh
#read -r -p "[INTERACTION] Do you want to apply hybris pathces? [y/N] " response
#if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
#then
    # Running this more than once cause error
    echo "Error is fine"
    git config --global user.email "you@example.com"
    git config --global user.name "Your Name"
    hybris-patches/apply-patches.sh --mb
    echo "End of error is fine"
#else
#    echo "ok."
#fi
rm -rf halium/fake_crypt

. /opt/tools/Halium-9.0/build/envsetup.sh

lunch lineage_$DEVICE-userdebug

#breakfast $DEVICE

echo '[+] Making rom...'

#mka mkbootimg
#export USE_HOST_LEX=yes

mka systemimage

echo "Started ended on `date`";

rm -rf /opt/target
mkdir /opt/target
cp  $ROOTDIR/out/target/product/$DEVICE/lineage-*.zip \
    $ROOTDIR/out/target/product/$DEVICE/system.img \
    $ROOTDIR/out/target/product/$DEVICE/halium-boot.img \
    $ROOTDIR/out/target/product/$DEVICE/vendor.img \
    $ROOTDIR/out/target/product/$DEVICE/dtbo.img \
    /opt/target/
