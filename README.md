## Build status

| Name | Build Status |
|----|----|
| make-flashable-zip | [![Build Status](https://oldpc.mrcyjanek.net:443/ci/job/ubports-gsi-make-flashable-zip/badge/icon)](https://oldpc.mrcyjanek.net:443/ci/job/ubports-gsi-make-flashable-zip/) |
| rootfs-builder-debos-android9 | [![Build Status](https://oldpc.mrcyjanek.net:443/ci/job/ubports-gsi-rootfs-builder-debos-android9/badge/icon)](https://oldpc.mrcyjanek.net:443/ci/job/ubports-gsi-rootfs-builder-debos-android9/) |
| rootfs-to-img | [![Build Status](https://oldpc.mrcyjanek.net:443/ci/job/ubports-gsi-rootfs-to-img/badge/icon)](https://oldpc.mrcyjanek.net:443/ci/job/ubports-gsi-rootfs-to-img/) |
| systemimage | [![Build Status](https://oldpc.mrcyjanek.net:443/ci/job/ubports-gsi-systemimage/badge/icon)](https://oldpc.mrcyjanek.net:443/ci/job/ubports-gsi-systemimage/) |
| docker-prepare-rootfs-to-img | [![Build Status](https://oldpc.mrcyjanek.net:443/ci/view/ubports-gsi/job/ubports-gsi-docker-prepare-rootfs-to-img/badge/icon)](https://oldpc.mrcyjanek.net:443/ci/view/ubports-gsi/job/ubports-gsi-docker-prepare-rootfs-to-img/) |

# Installation

 1. First of all, you need to [port halium-9.0](https://github.com/MrCyjaneK/Halium9-Docs/wiki/Build-Halium), and make sure that your device can run generic system images. 
 2. Then flash halium-boot.img and boot your device into TWRP
 3. Download [target.zip](http://oldpc/ci/view/ubports-gsi/job/ubports-gsi-make-flashable-zip/lastSuccessfulBuild/artifact/) and install it as zip.
 4. If needed flash halium-ramdisk.zip
