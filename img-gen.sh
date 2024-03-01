#!/usr/bin/env bash

set -e

if [ ! -d .buildroot ]; then
  echo "Downloading buildroot"
  git clone --single-branch -b 2022.02 https://github.com/buildroot/buildroot.git .buildroot
fi
# Remove old files
rm -rf ".buildroot/output/target/opt/shiki"
rm -rf ".buildroot/board/shiki/overlayfs"
rm -rf ".buildroot/board/shiki/p1"
rm -rf ".buildroot/board/shiki/p3"

# Get latest LKMs
echo "Getting latest LKMs"
if [ `ls ../shiki-lkm/output | wc -l` -eq 0 ]; then
  echo "  Downloading from github"
  TAG=`curl -s https://api.github.com/repos/andatoshiki/shiki-lkm/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}'`
  curl -L "https://github.com/andatoshiki/shiki-lkm/releases/download/${TAG}/shiki-lkms.zip" -o /tmp/shiki-lkms.zip
  rm -rf files/board/shiki/p3/lkms/*
  unzip /tmp/shiki-lkms.zip -d files/board/shiki/p3/lkms
else
  echo "  Copying from ../shiki-lkm/output"
  rm -rf files/board/shiki/p3/lkms/*
  cp -f ../shiki-lkm/output/* files/board/shiki/p3/lkms
fi

# Get latest addons and install its
echo "Getting latest Addons"
rm -Rf /tmp/addons
mkdir -p /tmp/addons
if [ -d ../shiki-addons ]; then
  cp ../shiki-addons/*.addon /tmp/addons/
else
  TAG=`curl -s https://api.github.com/repos/andatoshiki/shiki-addons/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}'`
  curl -L "https://github.com/andatoshiki/shiki-addons/releases/download/${TAG}/addons.zip" -o /tmp/addons.zip
  rm -rf /tmp/addons
  unzip /tmp/addons.zip -d /tmp/addons
fi
DEST_PATH="files/board/shiki/p3/addons"
echo "Installing addons to ${DEST_PATH}"
for PKG in `ls /tmp/addons/*.addon`; do
  ADDON=`basename ${PKG} | sed 's|.addon||'`
  mkdir -p "${DEST_PATH}/${ADDON}"
  echo "Extracting ${PKG} to ${DEST_PATH}/${ADDON}"
  tar xaf "${PKG}" -C "${DEST_PATH}/${ADDON}"
done

# Get latest modules
echo "Getting latest modules"
MODULES_DIR="${PWD}/files/board/shiki/p3/modules"
if [ -d ../shiki-modules ]; then
  cd ../shiki-modules
  for D in `ls -d *-*`; do
    echo "${D}"
    (cd ${D} && tar caf "${MODULES_DIR}/${D}.tgz" *.ko)
  done
  (cd firmware && tar caf "${MODULES_DIR}/firmware.tgz" *)
  cd -
else
  TAG=`curl -s https://api.github.com/repos/andatoshiki/shiki-modules/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}'`
  while read PLATFORM KVER; do
    FILE="${PLATFORM}-${KVER}"
    curl -L "https://github.com/andatoshiki/shiki-modules/releases/download/${TAG}/${FILE}.tgz" -o "${MODULES_DIR}/${FILE}.tgz"
  done < PLATFORMS
  curl -L "https://github.com/andatoshiki/shiki-modules/releases/download/${TAG}/firmware.tgz" -o "${MODULES_DIR}/firmware.tgz"
fi

# Copy files
echo "Copying files"
VERSION=`cat VERSION`
sed 's/^SHIKI_VERSION=.*/SHIKI_VERSION="'${VERSION}'"/' -i files/board/shiki/overlayfs/opt/shiki/include/consts.sh
echo "${VERSION}" > files/board/shiki/p1/SHIKI-VERSION
cp -Ru files/* .buildroot/

cd .buildroot
echo "Generating default config"
make BR2_EXTERNAL=../external -j`nproc` shiki_defconfig
echo "Version: ${VERSION}"
echo "Building... Drink a coffee and wait!"
make BR2_EXTERNAL=../external -j`nproc`
cd -
qemu-img convert -O vmdk shiki.img shiki-dyn.vmdk
qemu-img convert -O vmdk -o adapter_type=lsilogic shiki.img -o subformat=monolithicFlat shiki.vmdk
[ -x test.sh ] && ./test.sh
rm -f *.zip
zip -9 "shiki-${VERSION}.img.zip" shiki.img
zip -9 "shiki-${VERSION}.vmdk-dyn.zip" shiki-dyn.vmdk
zip -9 "shiki-${VERSION}.vmdk-flat.zip" shiki.vmdk shiki-flat.vmdk
sha256sum update-list.yml > sha256sum
zip -9j update.zip update-list.yml
while read F; do
  if [ -d "${F}" ]; then
    FTGZ="`basename "${F}"`.tgz"
    tar czf "${FTGZ}" -C "${F}" .
    sha256sum "${FTGZ}" >> sha256sum
    zip -9j update.zip "${FTGZ}"
    rm "${FTGZ}"
  else
    (cd `dirname ${F}` && sha256sum `basename ${F}`) >> sha256sum
    zip -9j update.zip "${F}"
  fi
done < <(yq '.replace | explode(.) | to_entries | map([.key])[] | .[]' update-list.yml)
zip -9j update.zip sha256sum 
rm -f sha256sum
