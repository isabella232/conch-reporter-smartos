#!/bin/bash -xe

GIT_VERSION=$( git rev-parse --short HEAD )

#[[ ! -z "$1" ]] && CONCH_SERVER=$1 ||  CONCH_SERVER="conch.joyent.us"
DIST_NAME="conch-reporter-smartos-${GIT_VERSION}"
DIST_ARCHIVE="${DIST_NAME}.tar.gz"
BUILD_BASE="/tmp"
BUILD_AREA="${BUILD_BASE}/${DIST_NAME}"

test -d ${BUILD_AREA} && rm -rf ${BUILD_AREA}
mkdir ${BUILD_AREA}

echo ${GIT_VERSION} > ${BUILD_AREA}/VERSION.txt
cp -R * ${BUILD_AREA}/

cd ${BUILD_AREA}

rm -rf ./.git
rm -rf ./local/cache

carton
cd /tmp

tar -czf ${DIST_ARCHIVE} ${DIST_NAME}
echo "${BUILD_BASE}/${DIST_ARCHIVE}"
