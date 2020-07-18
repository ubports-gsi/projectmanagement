#!/bin/bash
. config.sh
a=$(pwd)
echo "[+] Building rootfs."
if [[ ! -d "${GSI_ROOTDIR}/rootfs-builder-debos-android9" ]];
then
    # Directory doesn't exist, we will clone repo now.
    echo "[+] Cloning repo"
    git clone git@github.com:ubports-gsi/rootfs-builder-debos-android9.git "${GSI_ROOTDIR}/rootfs-builder-debos-android9"
else
    echo "[+] Pulling repo"
    cd "${GSI_ROOTDIR}/rootfs-builder-debos-android9"
    git pull
fi

cd "${GSI_ROOTDIR}/rootfs-builder-debos-android9"

docker run --rm --interactive --tty --device /dev/kvm --user $(id -u) --group-add kvm --workdir /recipes --mount "type=bind,source=$(pwd),destination=/recipes" --security-opt label=disable godebos/debos -m 5G android9-generic.yaml

cp ubuntu-touch-android9-armhf.tar.gz ../target/rootfs.tar.gz
