#!/usr/bin/env bash
set -eu

IMAGE="ubuntu:24.04"
BUILD_DIR="build-winlator-latest"
PACKAGE_DIR="package-winlator-latest-glibc"
ARCHIVE="box64-0.x.x.tzst"
LOADER="/data/data/com.winlator/files/rootfs/lib/ld-linux-aarch64.so.1"

docker run --rm \
  -v "$PWD:/src" \
  -w /src \
  "$IMAGE" \
  bash -lc "
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq
    apt-get install -y -qq \
      cmake \
      make \
      gcc-aarch64-linux-gnu \
      python3 \
      binutils \
      zstd

    rm -rf '$BUILD_DIR' '$PACKAGE_DIR' '$ARCHIVE'

    cmake -S . -B '$BUILD_DIR' \
      -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
      -DCMAKE_EXE_LINKER_FLAGS='-Wl,--dynamic-linker=$LOADER' \
      -DARM64=ON \
      -DWINLATOR_GLIBC=ON \
      -DARM_DYNAREC=ON \
      -DBAD_SIGNAL=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DCI=ON

    cmake --build '$BUILD_DIR' --parallel 2

    mkdir -p '$PACKAGE_DIR/usr/local/bin'

    strip --strip-unneeded \
      -o '$PACKAGE_DIR/usr/local/bin/box64' \
      '$BUILD_DIR/box64'

    cat > '$PACKAGE_DIR/BUILD-INFO.txt' <<EOF
Box64 v0.4.3 latest glibc test build

Toolchain: Ubuntu 24.04
Compiler: aarch64-linux-gnu-gcc
Build type: Release

CMake options:
-DARM64=ON
-DWINLATOR_GLIBC=ON
-DARM_DYNAREC=ON
-DBAD_SIGNAL=ON
-DCI=ON

Dynamic loader:
$LOADER

Expected GLIBC ABI:
GLIBC_2.39

Package layout:
usr/local/bin/box64
EOF

    tar --zstd \
      -C '$PACKAGE_DIR' \
      -cf '$ARCHIVE' \
      usr BUILD-INFO.txt

    echo
    echo '=== Binary ==='
    file '$PACKAGE_DIR/usr/local/bin/box64'

    echo
    echo '=== ELF interpreter ==='
    readelf -l '$PACKAGE_DIR/usr/local/bin/box64' | grep interpreter

    echo
    echo '=== GLIBC ABI ==='
    readelf --version-info '$PACKAGE_DIR/usr/local/bin/box64' \\
      | grep -o 'GLIBC_[0-9.]*' \\
      | sort -Vu

    echo
    echo '=== Archive ==='
    tar --zstd -tf '$ARCHIVE'
    ls -lh '$ARCHIVE'
    sha256sum '$ARCHIVE'
  "
