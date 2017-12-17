#!/bin/bash

#
# This script installs the required build-time dependencies
# and builds AppImages for AppImageKit
#

STRIP="strip"
STATIC_BUILD=1
JOBS=${JOBS:-1}
RUN_TESTS=0

while [ $1 ]; do
  case $1 in
    '--debug' | '-d' )
      STRIP="true"
      ;;
    '--use-shared-libs' | '-s' )
      STATIC_BUILD=0
      ;;
    '--run-tests' | '-t' )
      RUN_TESTS=1
      ;;
    '--clean' | '-c' )
      rm -rf build
      git clean -df
      rm -rf squashfuse/* squashfuse/.git
      rm -rf squashfs-tools/* squashfs-tools/.git
      exit
      ;;
    '--help' | '-h' )
      echo 'Usage: ./build.sh [OPTIONS]'
      echo
      echo 'OPTIONS:'
      echo '  -h, --help: Show this help screen'
      echo '  -d, --debug: Build with debug info.'
      echo '  -n, --no-dependencies: Do not try to install distro specific build dependencies.'
      echo '  -s, --use-shared-libs: Use distro provided shared versions of inotify-tools and openssl.'
      echo '  -c, --clean: Clean all artifacts generated by the build.'
      exit
      ;;
  esac

  shift
done


if cat /etc/*release | grep "CentOS" 2>&1 >/dev/null; then
    if [ -e /opt/rh/devtoolset-4/enable ]; then
        . /opt/rh/devtoolset-4/enable
    fi
fi

echo "$KEY" | md5sum

set -e
set -x

HERE="$(dirname "$(readlink -f "${0}")")"
cd "$HERE"

# Fetch git submodules
git submodule update --init --recursive

# Clean up from previous run
[ -d build/ ] && rm -rf build/

# Build AppImage
mkdir build
cd build

cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=ON
make -j$JOBS
make install DESTDIR=install_prefix/

if [ ! -z $RUN_TESTS ]; then
  ctest -V
fi

xxd src/runtime | head -n 1

# Do NOT strip runtime
find install_prefix/usr/bin/ -not -iname runtime -print -exec "$STRIP" "{}" \; 2>/dev/null

ls -lh install_prefix/usr/bin/
for FILE in install_prefix/usr/bin/*; do
  echo "$FILE"
  ldd "$FILE" || true
done

bash -ex "$HERE/build-appdirs.sh"

ls -lh

mkdir -p out
cp -r install_prefix/usr/bin/* appdirs/*.AppDir out/
