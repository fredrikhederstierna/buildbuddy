#!/bin/bash

# GNU Toolchain Build Buddy v1
#
# Simple wizard to download, configure and build the GNU toolchain
# targeting especially bare-metal cross-compilers for embedded systems.
#
# Written by Fredrik Hederstierna 2015
#
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <http://unlicense.org/>

# Some packages possibly needed:
#   libz-dev
#   libgmp-dev
#   libgpc-dev
#   libmpfr-dev
#   libboost-all-dev
# GDB also might use
#   texinfo
#   libncurses-dev
#   xz

# Set shell to exit if error (to debug and dump output use -ex)

set -e

# Setup defaults

TARGET_DEFAULT=arm-none-eabi
LANGUAGES_DEFAULT=c,c++

BINUTILS_VERSION_DEFAULT=2.25.1
GCC_VERSION_DEFAULT=5.2.0
NEWLIB_VERSION_DEFAULT=2.2.0
GDB_VERSION_DEFAULT=7.9.1

DEST_PATH_DEFAULT="/usr/local/gcc"
DEST_PATH_SUFFIX_DEFAULT=""

HARDFLOAT_DEFAULT="Y"
BUILD_GDB_DEFAULT="Y"
APPLY_PATCH_DEFAULT="Y"

DOWNLOAD_GNU_SERVER="http://ftp.gnu.org/gnu"
DOWNLOAD_NEWLIB_SERVER="ftp://sourceware.org/pub/newlib"

# Get user input what to build

printf "GNU Toolchain BuildBuddy v1\n"
printf "Enter information what you want to build:\n"

# Choose target

read -p "Please enter toolchain target [$TARGET_DEFAULT]: " TARGET
TARGET="${TARGET:-$TARGET_DEFAULT}"
echo -e "Toolchain target: $TARGET"

# Choose languages

read -p "Please enter languages to build [$LANGUAGES_DEFAULT]: " LANGUAGES
LANGUAGES="${LANGUAGES:-$LANGUAGES_DEFAULT}"
echo -e "Languages: $LANGUAGES"

# Build GDB?

printf "Should GDB be built? [$BUILD_GDB_DEFAULT]:"
read -r -n1 -d '' BUILD_GDB
if [[ $BUILD_GDB != "" ]]
then
  printf "\n"
fi
BUILD_GDB="${BUILD_GDB:-$BUILD_GDB_DEFAULT}"
if [[ $BUILD_GDB =~ ^[Yy]$ ]]
then
  BUILD_GDB="Yes"
else
  BUILD_GDB="No"
fi
echo -e "Build GDB: $BUILD_GDB"

# Choose tool versions to build

read -p "Please enter Binutils version [$BINUTILS_VERSION_DEFAULT]: " BINUTILS_VERSION
BINUTILS_VERSION="${BINUTILS_VERSION:-$BINUTILS_VERSION_DEFAULT}"
echo -e "Binutils version: $BINUTILS_VERSION"

read -p "Please enter GCC version [$GCC_VERSION_DEFAULT]: " GCC_VERSION
GCC_VERSION="${GCC_VERSION:-$GCC_VERSION_DEFAULT}"
echo -e "GCC version: $GCC_VERSION"

read -p "Please enter Newlib version [$NEWLIB_VERSION_DEFAULT]: " NEWLIB_VERSION
NEWLIB_VERSION="${NEWLIB_VERSION:-$NEWLIB_VERSION_DEFAULT}"
echo -e "Newlib version: $NEWLIB_VERSION"

if [[ $BUILD_GDB == "Yes" ]]
then
  read -p "Please enter GDB version [$GDB_VERSION_DEFAULT]: " GDB_VERSION
  GDB_VERSION="${GDB_VERSION:-$GDB_VERSION_DEFAULT}"
  echo -e "GDB version: $GDB_VERSION"
fi

# Choose toolchain destination build path

read -p "Please enter path where to build toolchain [$DEST_PATH_DEFAULT]: " DEST_PATH
DEST_PATH="${DEST_PATH:-$DEST_PATH_DEFAULT}"

read -p "Extra path suffix [$DEST_PATH_SUFFIX_DEFAULT]: " DEST_PATH_SUFFIX
DEST_PATH_SUFFIX="${DEST_PATH_SUFFIX:-$DEST_PATH_SUFFIX_DEFAULT}"
DEST="$DEST_PATH/$TARGET-toolchain-gcc-$GCC_VERSION$DEST_PATH_SUFFIX"

# Set float config

printf "Should GCC be built with hard float? [$HARDFLOAT_DEFAULT]: "
read -r -n1 -d '' HARDFLOAT
if [[ $HARDFLOAT != "" ]]
then
  printf "\n"
fi
HARDFLOAT="${HARDFLOAT:-$HARDFLOAT_DEFAULT}"
if [[ $HARDFLOAT =~ ^[Yy]$ ]]
then
  HARDFLOAT="Yes"
  DEST="$DEST-hardfloat"
else
  HARDFLOAT="No"
  DEST="$DEST-softfloat"
fi
echo -e "\nUse Hardfloat: $HARDFLOAT"
echo -e "Build toolchain into path: $DEST"

# Patches

printf "Apply patches? [$APPLY_PATCH_DEFAULT]: "
read -r -n1 -d '' APPLY_PATCH
if [[ $APPLY_PATCH != "" ]]
then
  printf "\n"
fi
APPLY_PATCH="${APPLY_PATCH:-$APPLY_PATCH_DEFAULT}"
if [[ $APPLY_PATCH =~ ^[Yy]$ ]]
then
  APPLY_PATCH="Yes"
else
  APPLY_PATCH="No"
fi
echo -e "\nApply patches: $APPLY_PATCH"

# Set build paths

BINUTILS_DIR="binutils-$BINUTILS_VERSION" 
GCC_DIR="gcc-$GCC_VERSION" 
NEWLIB_DIR="newlib-$NEWLIB_VERSION" 

BINUTILS_SRC_FILE="binutils-$BINUTILS_VERSION.tar.bz2"
GCC_SRC_FILE="gcc-$GCC_VERSION.tar.bz2"
NEWLIB_SRC_FILE="newlib-$NEWLIB_VERSION.tar.gz"

if [[ $BUILD_GDB == "Yes" ]]
then
  GDB_DIR="gdb-$GDB_VERSION" 
  GDB_SRC_FILE="gdb-$GDB_VERSION.tar.xz"
fi

# Set rwx access

umask 022 

# Download tar-balls if not present

# Check and Download Binutils

if [ ! -f  ${BINUTILS_SRC_FILE} ]; then
  echo -e Downloading: $BINUTILS_SRC_FILE
  wget $DOWNLOAD_GNU_SERVER/binutils/$BINUTILS_SRC_FILE
fi

# Check and Download GCC

if [ ! -f  ${GCC_SRC_FILE} ]; then
  echo -e Downloading: $GCC_SRC_FILE
  wget $DOWNLOAD_GNU_SERVER/gcc/gcc-$GCC_VERSION/$GCC_SRC_FILE
fi

# Check and Download Newlib

if [ ! -f  ${NEWLIB_SRC_FILE} ]; then
  echo -e Downloading: $NEWLIB_SRC_FILE
  wget $DOWNLOAD_NEWLIB_SERVER/$NEWLIB_SRC_FILE
fi

if [[ $BUILD_GDB == "Yes" ]]
then
  # Check and Download GDB
  if [ ! -f  ${GDB_SRC_FILE} ]; then
    echo -e Downloading: $GDB_SRC_FILE
    wget $DOWNLOAD_GNU_SERVER/gdb/$GDB_SRC_FILE
  fi
fi

# Unpack tar-balls: 'z' for gz, 'j' for bz2, 'J' for xz

rm -fr "$BINUTILS_DIR" "$GCC_DIR" "$NEWLIB_DIR"
echo -e "Unpacking binutils sources..."
tar xjf "$BINUTILS_SRC_FILE"
echo -e "Unpacking gcc sources..."
tar xjf "$GCC_SRC_FILE"
echo -e "Unpacking newlib sources..."
tar xzf "$NEWLIB_SRC_FILE"
if [[ $BUILD_GDB == "Yes" ]]
then
  rm -fr "$GDB_DIR"
  echo -e "Unpacking gdb sources..."
  tar xJf "$GDB_SRC_FILE"
fi

# Create sym links to newlib

cd "$GCC_DIR"
ln -s "../$NEWLIB_DIR/newlib" newlib 
ln -s "../$NEWLIB_DIR/libgloss" libgloss 
cd ..

# Remove if any old build dir

rm -fr build
mkdir -p build/binutils build/gcc build/newlib
if [[ $BUILD_GDB == "Yes" ]]
then
  mkdir -p build/gdb
fi

# Apply patches on sources
# Example: diff -crB --new-file ../gdb-7.9.1 . > ../patches/my_gdb.patch

if [[ $APPLY_PATCH == "Yes" ]]
then
  # Patches for GCC regrename
  echo -e "Applying patches..."
  ( cd $GCC_DIR ; patch -p1 -i ../patches/0001-Regrename-pass-with-preferred-register.patch ; )

  # Patches for arm-none GDB corefile support
  if [[ $TARGET == *"arm"* ]]
  then
    if [[ $BUILD_GDB == "Yes" ]]
    then
      if [[ $GDB_VERSION == "4.6.1" ]]
      then
        ( cd $GDB_DIR ; patch -p1 -i ../patches/gdb-4.6.1-arm-none-corefile.patch ; )
      fi
      if [[ $GDB_VERSION == "4.9.1" ]]
      then
        ( cd $GDB_DIR ; patch -p1 -i ../patches/gdb-4.9.1-arm-none-corefile.patch ; )
      fi
    fi
  fi
fi

# Start build

echo -e "All ready and done to go, starting compilation..."
sleep 2

# Build binutils

cd build/binutils 
"../../$BINUTILS_DIR/configure" --target="$TARGET" --prefix="$DEST" --disable-nls
make LDFLAGS=-s all install 

# Setup gcc build flags

WITH_OPTS="--with-gnu-as --with-gnu-ld --with-newlib --with-system-zlib"
DISABLE_OPTS="--disable-nls --disable-libssp"
ENABLE_OPTS="--enable-multilib"

# Target specific flags

# ARM specific flags

if [[ $TARGET == *"arm"* ]]
then
  TARGET_OPTS="--with-endian=little --with-abi=aapcs --disable-interwork --with-mode=thumb --with-cpu=cortex-m4"

  if [[ $HARDFLOAT == "Yes" ]]
  then
    WITH_FLOAT_OPTS="--with-float=hard --with-fpu=fpv4-sp-d16"
  else
    WITH_FLOAT_OPTS="--with-float=soft"
  fi
fi

# Build gcc

cd ../gcc 
PATH="$DEST/bin:$PATH" 
"../../$GCC_DIR/configure" --enable-languages="$LANGUAGES" --target="$TARGET" --prefix="$DEST" $WITH_OPTS $TARGET_OPTS $WITH_FLOAT_OPTS $DISABLE_OPTS $ENABLE_OPTS
make LDFLAGS=-s all all-gcc install install-gcc

# Build gdb

if [[ $BUILD_GDB == "Yes" ]]
then
  cd ../gdb 
  "../../$GDB_DIR/configure" --target="$TARGET" --prefix="$DEST"
  make -w all install
fi

# Remove uncompressed sources

cd ../.. 
rm -fr build "$BINUTILS_DIR" "$GCC_DIR" "$NEWLIB_DIR"
if [[ $BUILD_GDB == "Yes" ]]
then
  rm -fr "$GDB_DIR"
fi

# Done

echo -e "All done."
echo -e "Toolchain built into dir: " $DEST
