#!/bin/bash

LOCATION="$(dirname "$(readlink -f "$0")")"

# Defaults
export ROOTFS_RELEASE="ut"
export INSTALL_MODE="img"
export DO_COPY_SSH_KEY=false
export SSH_KEY=~/.ssh/id_rsa.pub
export DO_ZIP=false
export SYSTEM_AS_ROOT=false

function quiet() {
    cat > /dev/null
}

out=quiet

# Include functions
#source "$LOCATION/functions/misc.sh"

DEPENDENCIES=(qemu-utils binfmt-support qemu-user-static e2fsprogs sudo simg2img binutils)
BINARIES=(simg2img qemu-arm-static mkfs.ext4 qemu-img readelf)
for bin in ${BINARIES[@]}; do
	if ! sudo bash -c "command -v $bin" >/dev/null 2>&1; then
		echo "$bin not found in \$PATH"
		echo
		echo "make sure you have all dependencies installed."
		echo "dependencies: ${DEPENDENCIES[*]}"
		exit 1
	fi
done

# if qemu-arm-static exists, a sanely installed update-binfmts
# -should- have qemu-arm. try to enable it in case it isnt.
# This is only ran if the update-binfmts command is available
if sudo bash -c "command -v update-binfmts" >/dev/null 2>&1; then
	if ! sudo update-binfmts --display qemu-arm | grep -q "qemu-arm (enabled)"; then
		sudo update-binfmts --enable qemu-arm
	fi
fi





# parse options
export ROOTFS_RELEASE="ut"
export USERPASSWORD="phablet"
#		shift
#		ROOTPASSWORD="$1"
#		;;
DO_COPY_SSH_KEY=false

export ROOTFS_TAR="../target/rootfs.tar.gz"
export AND_IMAGE="../target/system.img"
if [ ! -f "$ROOTFS_TAR" ] || [ ! -f "$AND_IMAGE" ]; then
	echo "Images not found!"
	exit
fi



export ROOTFS_DIR="${ROOTFS_DIR:-$(mktemp -d .halium-install-rootfs.XXXXX)}"
export IMAGE_DIR="${IMAGE_DIR:-$(mktemp -d .halium-install-imgs.XXXXX)}"

# Logic that depends on the opts being parsed

#source "$LOCATION/functions/distributions.sh"

case "$ROOTFS_RELEASE" in
halium | reference)
	IMAGE_SIZE=1G
	;;
pm | neon | debian-pm | debian-pm-caf)
	IMAGE_SIZE=4G
	;;
ut)
	IMAGE_SIZE=3G
	;;
none)
	IMAGE_SIZE=2G
	;;
esac

do_until_success() {
	while ! "$@"; do
		echo "Failed, please try again"
	done
}

function setup_passwd() {
	user=$1
	pass=$2
	if [ -z "$pass" ] ; then
		echo "Please enter a new password for the user '$user':"
		do_until_success sudo chroot "$ROOTFS_DIR" passwd $user
	else
		echo "I: Setting new password for the user '$user'"
		echo $user:$pass | sudo chroot "$ROOTFS_DIR" chpasswd
	fi
}

function chroot_run() {
	sudo PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" DEBIAN_FRONTEND=noninteractive LANG=C RUNLEVEL=1 chroot "$ROOTFS_DIR" /bin/bash -c "$@"
}

function copy_ssh_key_root() {
	if $DO_COPY_SSH_KEY ; then
		D="$ROOTFS_DIR/root/.ssh"
		echo "I: Copying ssh key to the user 'root'"

		sudo mkdir "$D"
		sudo tee -a "$D/authorized_key"s < $SSH_KEY >/dev/null
		sudo chmod 0700 "$D"
		sudo chmod 0600 "$D/authorized_keys"
	fi
}

function copy_ssh_key_phablet() {
	if $DO_COPY_SSH_KEY ; then
		D="$ROOTFS_DIR/home/phablet/.ssh"
		echo "I: Copying ssh key to the user 'phablet'"

		sudo mkdir "$D"
		sudo tee -a "$D/authorized_keys" < $SSH_KEY >/dev/null
		sudo chown -R 32011:32011 "$D"
		sudo chmod 0700 "$D"
		sudo chmod 0600 "$D/authorized_keys"
	fi
}

function post_install() {
	if [ "$1" == "none" ]; then
		return
	fi

	architecture="$(readelf -h $ROOTFS_DIR/bin/sh | grep Machine | sed -e 's/^.*Machine: //' | xargs)"

	case $architecture in
	"ARM") qemu="qemu-arm-static" ;;
	"AArch64") qemu="qemu-aarch64-static" ;;
	*) qemu="qemu-arm-static" ;;
	esac

	sudo cp $(command -v $qemu) "$ROOTFS_DIR/usr/bin"
	sudo cp /etc/resolv.conf "$ROOTFS_DIR/etc/"
	case "$1" in
	halium | reference)
		setup_passwd root $ROOTPASSWORD
		copy_ssh_key_root

		if chroot_run "id -u phablet" >/dev/null 2>&1; then
			setup_passwd phablet $USERPASSWORD
			copy_ssh_key_phablet
		fi

		sudo rm -f "$ROOTFS_DIR"/etc/dropbear/dropbear_{dss,ecdsa,rsa}_host_key
		chroot_run "dpkg-reconfigure dropbear-run"
		;;
	# Dropbear in debian moved from dropbear-run to the dropbear package.
	# TODO: Remove duplication once reference rootfs and debian-pm are on the same state again.
	debian-pm)
		setup_passwd root $ROOTPASSWORD
		copy_ssh_key_root

		if chroot_run "id -u phablet" >/dev/null 2>&1; then
			setup_passwd phablet $USERPASSWORD
			copy_ssh_key_phablet
		fi

		sudo rm -f "$ROOTFS_DIR"/etc/dropbear/dropbear_{dss,ecdsa,rsa}_host_key
		chroot_run "dpkg-reconfigure dropbear"
		;;
	debian-pm-caf)
		setup_passwd root $ROOTPASSWORD
		copy_ssh_key_root

		if chroot_run "id -u phablet" >/dev/null 2>&1; then
			setup_passwd phablet $USERPASSWORD
			copy_ssh_key_phablet
		fi

		sudo rm -f "$ROOTFS_DIR"/etc/dropbear/dropbear_{dss,ecdsa,rsa}_host_key
		chroot_run "dpkg-reconfigure dropbear"

		echo "Adding repository for libhybris platform caf"
		chroot_run "echo 'deb https://repo.kaidan.im/debpm testing caf' > /etc/apt/sources.list.d/debian-pm.list"

		chroot_run "apt update && apt full-upgrade -y"
		;;
	pm | neon)
		setup_passwd root $ROOTPASSWORD
		copy_ssh_key_root
		setup_passwd phablet $USERPASSWORD
		copy_ssh_key_phablet

		# cant source /etc/environment
		# LD_LIBRARY_ ; QML2_IMPORT_ derps
		# set static path for now
		chroot_run "dpkg-reconfigure openssh-server"
		;;
	ut)
		# Adapted from rootstock-ng
		echo -n "enabling Mir ... "
		sudo touch "$ROOTFS_DIR/home/phablet/.display-mir"
		echo "[done]"

		echo -n "enabling SSH ... "
		sudo sed -i 's/PasswordAuthentication=no/PasswordAuthentication=yes/g' "$ROOTFS_DIR/etc/init/ssh.override"
		sudo sed -i 's/manual/start on startup/g' "$ROOTFS_DIR/etc/init/ssh.override"
		sudo sed -i 's/manual/start on startup/g' "$ROOTFS_DIR/etc/init/usb-tethering.conf"
		echo "[done]"

		setup_passwd phablet $USERPASSWORD
		copy_ssh_key_phablet

		sudo mkdir -p "$ROOTFS_DIR/android/firmware"
		sudo mkdir -p "$ROOTFS_DIR/android/persist"
		sudo mkdir -p "$ROOTFS_DIR/userdata"
		for link in cache data factory firmware persist system odm product metadata; do
			sudo ln -s /android/$link "$ROOTFS_DIR/$link"
		done
		sudo ln -s /system/lib/modules "$ROOTFS_DIR/lib/modules"
		sudo ln -s /android/vendor "$ROOTFS_DIR/vendor"
		[ -e rootfs/etc/mtab ] && sudo rm "$ROOTFS_DIR/etc/mtab"
		sudo ln -s /proc/mounts "$ROOTFS_DIR/etc/mtab"
		;;
	esac
	sudo rm "$ROOTFS_DIR/usr/bin/$qemu"
}

#source "$LOCATION/functions/core.sh"

function convert_rootfs_to_img() {
	image_size=$1

	qemu-img create -f raw "$IMAGE_DIR/rootfs.img" $image_size
	sudo mkfs.ext4 -O ^metadata_csum -O ^64bit -F "$IMAGE_DIR/rootfs.img"
	sudo mount "$IMAGE_DIR/rootfs.img" "$ROOTFS_DIR"
	sudo tar --numeric-owner -xpf "$ROOTFS_TAR" -C "$ROOTFS_DIR"
}

function convert_rootfs_to_dir() {
	sudo tar --numeric-owner -xpf "$ROOTFS_TAR" -C "$ROOTFS_DIR"
}

function convert_androidimage() {
	if file "$AND_IMAGE" | grep "ext[2-4] filesystem"; then
		cp "$AND_IMAGE" "$IMAGE_DIR/system.img"
	else
		simg2img "$AND_IMAGE" "$IMAGE_DIR/system.img"
	fi
}

function shrink_images() {
	[ -f "$IMAGE_DIR/system.img" ] && sudo e2fsck -fy "$IMAGE_DIR/system.img" >/dev/null || true
	[ -f "$IMAGE_DIR/system.img" ] && sudo resize2fs -p -M "$IMAGE_DIR/system.img"
}

function inject_androidimage() {
	# Move android image into rootfs location (https://github.com/Halium/initramfs-tools-halium/blob/halium/scripts/halium#L259)
	sudo mv "$IMAGE_DIR/system.img" "$ROOTFS_DIR/var/lib/lxc/android/"

	# Make sure the mount path is correct
	if chroot_run "command -v dpkg-divert"; then # On debian distros, use dpkg-divert
		chroot_run "dpkg-divert --add --rename --divert /lib/systemd/system/system.mount.image /lib/systemd/system/system.mount"
		sed 's,/data/system.img,/var/lib/lxc/android/system.img,g' "$ROOTFS_DIR/lib/systemd/system/system.mount.image" | sudo tee -a "$ROOTFS_DIR/lib/systemd/system/system.mount" >/dev/null 2>&1
	else # Else just replace the path directly (not upgrade safe)
		sed -i 's,/data/system.img,/var/lib/lxc/android/system.img,g' "$ROOTFS_DIR/lib/systemd/system/system.mount.image"
	fi
}

function unmount() {
	sudo umount "$ROOTFS_DIR"
}

function flash_img() {
	if $DO_ZIP ; then
		echo "I:    Compressing rootfs on host"
		pigz --fast "$IMAGE_DIR/rootfs.img"
		echo "I:    Pushing rootfs to /data via ADB"
		adb push "$IMAGE_DIR/rootfs.img.gz" /data/
		echo "I:    Decompressing rootfs on device"
		adb shell "gunzip -f /data/rootfs.img.gz"

		echo "I:    Compressing android image on host"
		pigz --fast "$IMAGE_DIR/system.img"
		echo "I:    Pushing android image to /data via ADB"
		adb push "$IMAGE_DIR/system.img.gz" /data/
		echo "I:    Decompressing android image on device"
		adb shell "gunzip -f /data/system.img.gz"
	else
		echo "I:    Pushing rootfs to /data via ADB"
		adb push "$IMAGE_DIR/rootfs.img" /data/
		echo "I:    Pushing android image to /data via ADB"
		adb push "$IMAGE_DIR/system.img" /data/
	fi

	if $SYSTEM_AS_ROOT; then
		echo "I:    Renaming to system-as-root compatible system image"
		adb shell "mv /data/system.img /data/android-rootfs.img"
	fi
}

function flash_dir() {
	adb push "$ROOTFS_DIR"/* /data/halium-rootfs/
}

function clean() {
	sudo rm "$ROOTFS_DIR" "$IMAGE_DIR" -rf
}

function clean_device() {
	# Make sure the device is in a clean state
	adb shell sync
}

function clean_exit() {
	echo "I: Cleaning up"
	unmount || true
	clean || true
	clean_device || true
}


# Always enforce cleanup on exit
if [ -z ${TEST_MODE} ]; then
	trap clean_exit EXIT
fi

# Start installer
echo "Debug: Chosen rootfs is $ROOTFS_TAR"
echo "Debug: Chosen android image is $AND_IMAGE"
echo "Debug: Chosen release is $ROOTFS_RELEASE"
echo "Debug: Compress images before pushing: $DO_ZIP"
echo

case "$INSTALL_MODE" in
"img")
	echo "I: Writing rootfs into mountable image"
	convert_rootfs_to_img $IMAGE_SIZE 2>&1 | $out
	;;
"dir")
	echo "I: Extracting rootfs"
	convert_rootfs_to_dir 2>&1 | $out
	;;
esac

echo "I: Writing android image into mountable image"
convert_androidimage 2>&1 | $out

echo "I: Running post installation tasks"
post_install $ROOTFS_RELEASE

echo "I: Shrinking images"
shrink_images

case "$INSTALL_MODE" in
"img")
	# In dir mode, nothing is being mounted, so unmount would fail
	echo "I: Unmounting images"
	unmount
	;;
"dir")
	echo "I: Injecting android image into rootfs"
	inject_androidimage
	;;
esac

cp "$IMAGE_DIR"/system.img ../target/target-system.img
cp "$IMAGE_DIR"/rootfs.img ../target/target-rootfs.img

#rm "$ROOTFS_TAR" "$AND_IMAGE"

unmount

rm -rf "$IMAGE_DIR" "$ROOTFS_DIR"


#if [ -z ${TEST_MODE} ]; then
#	case "$INSTALL_MODE" in
#	"img")
#		echo "I: Pushing rootfs and android image to /data via ADB"
#		if ! time flash_img; then
#			echo "Error: Couldn't copy the files to the device, is it connected?"
#		fi
#		;;
#	"dir")
#		echo "I: Pushing rootfs and android image to /data via ADB"
#		if ! flash_dir; then
#			echo "Error: Couldn't copy the files to the device, is it connected?"
#		fi
#		;;
#	esac
#fi
