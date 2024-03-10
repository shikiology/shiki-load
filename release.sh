#!/usr/bin/env bash

set -e

TMP_PATH="./tmp"
DEST_PATH="./output"
TOOLKIT_VER="7.2-ubuntu-amd64"

mkdir -p "${DEST_PATH}"


curl -sLO "https://gitlab.com/toshikidev/shikiology/shiki-v1/shiki-load/-/raw/master/PLATFORMS"

function compileLkm() {
  PLATFORM=$1
  KVER=$2
  OUT_PATH="${TMP_PATH}/${PLATFORM}"
  mkdir -p "${OUT_PATH}"
  sudo chmod 1777 "${OUT_PATH}"
  # Compile using docker
#  docker run --rm -t -v "${OUT_PATH}":/output -v "${PWD}":/input \
#    fbelavenuto/syno-toolkit:${PLATFORM}-${TOOLKIT_VER} compile-lkm
  docker run -u 1000 --rm -t -v "${OUT_PATH}":/output -v "${PWD}":/input \
    andatoshiki/shiki-compiler:${TOOLKIT_VER} compile-lkm ${PLATFORM}
  mv "${OUT_PATH}/shiki-dev.ko" "${DEST_PATH}/shiki-${PLATFORM}-${KVER}-dev.ko"
  rm -f "${DEST_PATH}/shiki-${PLATFORM}-${KVER}-dev.ko.gz"
  gzip "${DEST_PATH}/shiki-${PLATFORM}-${KVER}-dev.ko"
  mv "${OUT_PATH}/shiki-prod.ko" "${DEST_PATH}/shiki-${PLATFORM}-${KVER}-prod.ko"
  rm -f "${DEST_PATH}/shiki-${PLATFORM}-${KVER}-prod.ko.gz"
  gzip "${DEST_PATH}/shiki-${PLATFORM}-${KVER}-prod.ko"
  rm -rf "${OUT_PATH}"
}

# Main
docker pull andatoshiki/shiki-compiler:${TOOLKIT_VER}
while read PLATFORM KVER; do
#  docker pull fbelavenuto/syno-toolkit:${PLATFORM}-${TOOLKIT_VER}
  compileLkm "${PLATFORM}" "${KVER}" &
done < PLATFORMS
wait

rm -f PLATFORMS