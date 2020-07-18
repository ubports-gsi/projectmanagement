. config.sh

echo "[+] Stopping and deleting container"
sudo docker stop ubports-gsi
sudo docker container rm ubports-gsi
echo "[+] Preparing container..."
sudo docker run -i -t -v $(pwd)/build:/opt/ \
    --privileged=true \
    --name="ubports-gsi"\
    ubuntu:16.04 sh -c "echo '============='
apt update;
echo '=== Installing tools';
apt install git -y;
dpkg --add-architecture i386;
apt update;
apt install ccache git gnupg flex bison gperf build-essential \
  zip bzr curl libc6-dev libncurses5-dev:i386 x11proto-core-dev \
  libx11-dev:i386 libreadline6-dev:i386 libgl1-mesa-glx:i386 \
  libgl1-mesa-dev g++-multilib mingw-w64-i686-dev tofrodos \
  python-markdown libxml2-utils xsltproc zlib1g-dev:i386 schedtool \
  repo liblz4-tool bc lzop imagemagick libncurses5 rsync wget -y;
wget https://storage.googleapis.com/git-repo-downloads/repo -O /bin/repo;
chmod +x /bin/repo;
exit";
echo "[+] Removing old image"
sudo docker image rm --force ubports-gsi/builder:latest
echo "[+] Commiting container image"
sudo docker commit \
    --author "Czarek Nakamoto (mrcyjanek.net)" \
    ubports-gsi \
    ubports-gsi/builder:latest
echo "[+] Stopping and deleting container"
sudo docker stop ubports-gsi
sudo docker container rm ubports-gsi
