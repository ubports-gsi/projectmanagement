#!/bin/bash
. config.sh

echo "[+] Building system.img."
sudo docker run -it -v "${GSI_ROOTDIR}":/opt/ \
    --privileged=true \
    --rm ubports-gsi/builder:latest sh -c "cd /opt/projectmanagement && bash build-system-image-docker.sh"
