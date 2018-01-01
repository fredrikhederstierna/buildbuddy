#!/bin/bash

# GNU Toolchain Build Buddy v1.0.8
#
# Simple wizard to download, configure and build the GNU toolchain
# targeting especially bare-metal cross-compilers for embedded systems.
#
# Written by Fredrik Hederstierna 2015/2016/2017
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

#
# ChangeLog history:
#
# 1.0    Initial release
# 1.0.1  Fix that GDB prior to 7.8 used bz2 not xz as compressor.
# 1.0.2  Fix that GDB version sorting handles that 7.9 < 7.10.
# 1.0.3  Updated corefile patch for GDB version 7.11.1.
# 1.0.4  Added optional WGET proxy settings for HTTP and FTP.
# 1.0.5  Removed Guile support in GDB --with-guile=no
#        (https://sourceware.org/bugzilla/show_bug.cgi?id=21104)
#        Disable generation of docs in GDB: MAKEINFO=true
#        Parallelize make with --jobs=NCORE option.
#        Print out time consumed for build diagnostics.
# 1.0.6  Attempt to make it possible to build older arm cross-gcc
#        with target arm-elf like gcc-3.x. Seems like eabi gcc-4.x
#        also has some issues to be built with versions < gcc-4.6.x.
#        To build gcc-3.4.6, use TARGET=arm-thumb-elf, newlib-1.12.0.
# 1.0.7  Made gcc-4.4.7 and gcc-4.5.4 compile for arm-eabi by forcing
#        -std=gnu89 and disabled doc generation with MAKEINFO=missing,
#        needed newlib-1.19.0 to compile.
# 1.0.8  Fix that GCC prior to 7.2 used bz2 not xz as compressor.
#        Fix that BINUTILS prior to 2.29 used bz2 not xz as compressor.
#

# Some packages possibly needed:
#   libz-dev
#   libgmp-dev
#   libmpc-dev
#   libmpfr-dev
#   libboost-all-dev
# GDB also might use
#   texinfo
#   libncurses-dev
#   xz
#
# From GCC 5.3 also this seems needed:
#   libisl-dev

# BUGS:
# Binutils 2.25.1 assembler does not support 'cortex-m7' cpu option.
# https://bugs.archlinux.org/task/46951
#
# TODO:
# * Make interactive optional, possible to input all parameters as arguments.
# * Add more targets like avr, mips, msp430, i386 etc.
#

# Set shell to exit if error (to debug and dump output use -ex)

set -e

# Setup defaults

TARGET_DEFAULT=arm-none-eabi
LANGUAGES_DEFAULT=c,c++

BINUTILS_VERSION_DEFAULT=2.29.1
GCC_VERSION_DEFAULT=7.2.0
NEWLIB_VERSION_DEFAULT=2.5.0
GDB_VERSION_DEFAULT=8.0.1

DEST_PATH_DEFAULT="/usr/local/gcc"
DEST_PATH_SUFFIX_DEFAULT=""

HARDFLOAT_DEFAULT="Y"
BUILD_GDB_DEFAULT="Y"
APPLY_PATCH_DEFAULT="Y"

DOWNLOAD_GNU_SERVER="http://ftp.gnu.org/gnu"
DOWNLOAD_NEWLIB_SERVER="ftp://sourceware.org/pub/newlib"

BINUTILS_ARCH_SUFFIX=""
GCC_ARCH_SUFFIX=""
GDB_ARCH_SUFFIX=""

# Extra proxy settings if needed for wget

WGET_HTTP_PROXY_EXTRA=""
#WGET_HTTP_PROXY_EXTRA="-e use_proxy=yes -e http_proxy=127.0.0.1:8080"
WGET_FTP_PROXY_EXTRA=""
#WGET_FTP_PROXY_EXTRA="-e use_proxy=yes -e ftp_proxy=127.0.0.1:8080"

# Get max CPU cores to parallelize make
# If this causes problems, just set PARALLEL_EXE=""
# Sometimes I've observed that gcc-build just stops too early without error

NPROCESS=`getconf _NPROCESSORS_ONLN`
NTHREAD=$(($NPROCESS*2))
PARALLEL_EXE="--jobs=$NTHREAD --max-load=$NTHREAD"

# Get user input what to build

printf "GNU Toolchain BuildBuddy v1.0.8\n"
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
# Use version sort to get lowest version
BINUTILS_VERSION_MIN=`echo -ne "2.29\n$BINUTILS_VERSION" |sort -V |head -n1`
# From version 2.29 and newer BINUTILS use xz as compression algorithm
if [[ $BINUTILS_VERSION_MIN < "2.29" ]]
then
 echo -e "Use bz2 for decompression"
 BINUTILS_ARCH_SUFFIX="bz2"
else
 echo -e "Use xz for decompression"
 BINUTILS_ARCH_SUFFIX="xz"
fi

read -p "Please enter GCC version [$GCC_VERSION_DEFAULT]: " GCC_VERSION
GCC_VERSION="${GCC_VERSION:-$GCC_VERSION_DEFAULT}"
echo -e "GCC version: $GCC_VERSION"
# Use version sort to get lowest version
GCC_VERSION_MIN=`echo -ne "7.2\n$GCC_VERSION" |sort -V |head -n1`
# From version 7.2 and newer GCC use xz as compression algorithm
if [[ $GCC_VERSION_MIN < "7.2" ]]
then
 echo -e "Use bz2 for decompression"
 GCC_ARCH_SUFFIX="bz2"
else
 echo -e "Use xz for decompression"
 GCC_ARCH_SUFFIX="xz"
fi

read -p "Please enter Newlib version [$NEWLIB_VERSION_DEFAULT]: " NEWLIB_VERSION
NEWLIB_VERSION="${NEWLIB_VERSION:-$NEWLIB_VERSION_DEFAULT}"
echo -e "Newlib version: $NEWLIB_VERSION"

if [[ $BUILD_GDB == "Yes" ]]
then
  read -p "Please enter GDB version [$GDB_VERSION_DEFAULT]: " GDB_VERSION
  GDB_VERSION="${GDB_VERSION:-$GDB_VERSION_DEFAULT}"
  echo -e "GDB version: $GDB_VERSION"
  # Use version sort to get lowest version
  GDB_VERSION_MIN=`echo -ne "7.8\n$GDB_VERSION" |sort -V |head -n1`
  # From version 7.8 and newer GDB use xz as compression algorithm
  if [[ $GDB_VERSION_MIN < "7.8" ]]
  then
   echo -e "Use bz2 for decompression"
   GDB_ARCH_SUFFIX="bz2"
  else
   echo -e "Use xz for decompression"
   GDB_ARCH_SUFFIX="xz"
  fi
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

NEWLIB_SRC_FILE="newlib-$NEWLIB_VERSION.tar.gz"

if [[ $BINUTILS_ARCH_SUFFIX == "xz" ]]
then
  BINUTILS_SRC_FILE="binutils-$BINUTILS_VERSION.tar.xz"
else
  BINUTILS_SRC_FILE="binutils-$BINUTILS_VERSION.tar.bz2"
fi

if [[ $GCC_ARCH_SUFFIX == "xz" ]]
then
  GCC_SRC_FILE="gcc-$GCC_VERSION.tar.xz"
else
  GCC_SRC_FILE="gcc-$GCC_VERSION.tar.bz2"
fi

if [[ $BUILD_GDB == "Yes" ]]
then
  GDB_DIR="gdb-$GDB_VERSION"
  if [[ $GDB_ARCH_SUFFIX == "xz" ]]
  then
    GDB_SRC_FILE="gdb-$GDB_VERSION.tar.xz"
  else
    GDB_SRC_FILE="gdb-$GDB_VERSION.tar.bz2"
  fi
fi

# Set rwx access

umask 022 

# Download tar-balls if not present

# Check and Download Binutils

if [ ! -f  ${BINUTILS_SRC_FILE} ]; then
  echo -e Downloading: $BINUTILS_SRC_FILE
  wget $WGET_HTTP_PROXY_EXTRA $DOWNLOAD_GNU_SERVER/binutils/$BINUTILS_SRC_FILE
fi

# Check and Download GCC

if [ ! -f  ${GCC_SRC_FILE} ]; then
  echo -e Downloading: $GCC_SRC_FILE
  wget $WGET_HTTP_PROXY_EXTRA $DOWNLOAD_GNU_SERVER/gcc/gcc-$GCC_VERSION/$GCC_SRC_FILE
fi

# Check and Download Newlib

if [ ! -f  ${NEWLIB_SRC_FILE} ]; then
  echo -e Downloading: $NEWLIB_SRC_FILE
  wget $WGET_FTP_PROXY_EXTRA $DOWNLOAD_NEWLIB_SERVER/$NEWLIB_SRC_FILE
fi

if [[ $BUILD_GDB == "Yes" ]]
then
  # Check and Download GDB
  if [ ! -f  ${GDB_SRC_FILE} ]; then
    echo -e Downloading: $GDB_SRC_FILE
    wget $WGET_HTTP_PROXY_EXTRA $DOWNLOAD_GNU_SERVER/gdb/$GDB_SRC_FILE
  fi
fi

# Unpack tar-balls: 'z' for gz, 'j' for bz2, 'J' for xz

rm -fr "$BINUTILS_DIR" "$GCC_DIR" "$NEWLIB_DIR"

echo -e "Unpacking binutils sources..."
if [[ $BINUTILS_ARCH_SUFFIX == "xz" ]]
then
  tar xJf "$BINUTILS_SRC_FILE"
else
  tar xjf "$BINUTILS_SRC_FILE"
fi

echo -e "Unpacking gcc sources..."
if [[ $GCC_ARCH_SUFFIX == "xz" ]]
then
  tar xJf "$GCC_SRC_FILE"
else
  tar xjf "$GCC_SRC_FILE"
fi


echo -e "Unpacking newlib sources..."
tar xzf "$NEWLIB_SRC_FILE"

if [[ $BUILD_GDB == "Yes" ]]
then
  rm -fr "$GDB_DIR"
  echo -e "Unpacking gdb sources..."
  if [[ $GDB_ARCH_SUFFIX == "xz" ]]
  then
    tar xJf "$GDB_SRC_FILE"
  else
    tar xjf "$GDB_SRC_FILE"
  fi
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

  # Add patches here to apply, example
  #( cd $GCC_DIR ; patch -p1 -i ../patches/0001-Regrename-pass-with-preferred-register.patch ; )

  # Patch to make gcc-3.4.6 build with newer native gcc-4.x compiler
  if [[ $GCC_VERSION == "3.4.6" ]]
  then
    ( cd $GCC_DIR ; patch -p1 -i ../patches/gcc-3.4.6-ocreatmode.patch ; )
  fi

  # Patches for arm-none GDB corefile support
  if [[ $TARGET == *"arm"* ]]
  then
    if [[ $BUILD_GDB == "Yes" ]]
    then
      if [[ $GDB_VERSION == "7.6.1" ]]
      then
        ( cd $GDB_DIR ; patch -p1 -i ../patches/gdb-7.6.1-arm-none-corefile.patch ; )
      fi
      if [[ $GDB_VERSION == "7.9.1" ]]
      then
        ( cd $GDB_DIR ; patch -p1 -i ../patches/gdb-7.9.1-arm-none-corefile.patch ; )
      fi
      if [[ $GDB_VERSION == "7.11.1" ]]
      then
#        ( cd $GDB_DIR ; patch -p1 -i ../patches/gdb-7.11.1-arm-none-corefile.patch ; )
        ( cd $GDB_DIR ; patch -p1 -i ../patches/gdb-7.11.1-arm-none-corefile-unwind.patch ; )
      fi
    fi
  fi
fi

# Start build

echo -e "All ready and done to go, starting compilation..."
sleep 2

# Create time stamp of build start, use internal bash SECONDS counter

SECONDS=0
TIMESTAMP_BUILD_TOTAL_START=$SECONDS

# Build binutils

cd build/binutils 
TIMESTAMP_BUILD_BINUTILS_START=$SECONDS
"../../$BINUTILS_DIR/configure" --target="$TARGET" --prefix="$DEST" --disable-nls
make $PARALLEL_EXE LDFLAGS=-s all MAKEINFO=missing
make install
TIMESTAMP_BUILD_BINUTILS_END=$SECONDS

# Setup gcc build flags

WITH_OPTS="--with-gnu-as --with-gnu-ld --with-newlib --with-system-zlib"
DISABLE_OPTS="--disable-nls --disable-libssp"
ENABLE_OPTS=""

# Target specific flags

# ARM specific flags, example tune for Cortex-M4(F)

if [[ $TARGET == *"arm"* ]]
then
  TARGET_OPTS="--with-endian=little --disable-interwork"

  # Older gcc-3.4.6 do not use eabi, use arm-elf default abi
  if [[ $TARGET == *"eabi"* ]]
  then
    EXTRA_TARGET_OPTS="--enable-multilib"
    WITH_ABI_OPTS="--with-mode=thumb --with-abi=aapcs --with-cpu=cortex-m4"
  else
    EXTRA_TARGET_OPTS="--enable-multilib --enable-targets=arm-elf"
    WITH_ABI_OPTS="--with-cpu=arm7tdmi"
  fi

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
TIMESTAMP_BUILD_GCC_START=$SECONDS
"../../$GCC_DIR/configure" --enable-languages="$LANGUAGES" --target="$TARGET" --prefix="$DEST" $WITH_OPTS $TARGET_OPTS $WITH_ABI_OPTS $WITH_FLOAT_OPTS $DISABLE_OPTS $EXTRA_TARGET_OPTS $ENABLE_OPTS
make CFLAGS='-std=gnu89' $PARALLEL_EXE LDFLAGS=-s all MAKEINFO=missing
make CFLAGS='-std=gnu89' $PARALLEL_EXE LDFLAGS=-s all-gcc MAKEINFO=missing
make install-gcc
make install
TIMESTAMP_BUILD_GCC_END=$SECONDS

# Build gdb

if [[ $BUILD_GDB == "Yes" ]]
then
  cd ../gdb 
  TIMESTAMP_BUILD_GDB_START=$SECONDS
  "../../$GDB_DIR/configure" --target="$TARGET" --prefix="$DEST" --with-guile=no
  make $PARALLEL_EXE --print-directory all MAKEINFO=true
  make install
  TIMESTAMP_BUILD_GDB_END=$SECONDS
fi

# All sources built

TIMESTAMP_BUILD_TOTAL_END=$SECONDS
echo -e "All done."

# Remove uncompressed sources

cd ../.. 
rm -fr build "$BINUTILS_DIR" "$GCC_DIR" "$NEWLIB_DIR"
if [[ $BUILD_GDB == "Yes" ]]
then
  rm -fr "$GDB_DIR"
fi

# Print build statistics

TIME_BINUTILS_TOTAL=$(( $TIMESTAMP_BUILD_BINUTILS_END - $TIMESTAMP_BUILD_BINUTILS_START ))
echo "Build time Binutils: $(($TIME_BINUTILS_TOTAL / 3600)) hours, $((($TIME_BINUTILS_TOTAL / 60) % 60)) minutes and $(($TIME_BINUTILS_TOTAL % 60)) seconds."
TIME_GCC_TOTAL=$(( $TIMESTAMP_BUILD_GCC_END - $TIMESTAMP_BUILD_GCC_START ))
echo "Build time GCC     : $(($TIME_GCC_TOTAL / 3600)) hours, $((($TIME_GCC_TOTAL / 60) % 60)) minutes and $(($TIME_GCC_TOTAL % 60)) seconds."
if [[ $BUILD_GDB == "Yes" ]]
then
  TIME_GDB_TOTAL=$(( $TIMESTAMP_BUILD_GDB_END - $TIMESTAMP_BUILD_GDB_START ))
  echo "Build time GDB     : $(($TIME_GDB_TOTAL / 3600)) hours, $((($TIME_GDB_TOTAL / 60) % 60)) minutes and $(($TIME_GDB_TOTAL % 60)) seconds."
fi
TIME_TOTAL=$(( $TIMESTAMP_BUILD_TOTAL_END - $TIMESTAMP_BUILD_TOTAL_START ))
echo "Build time Total  : $(($TIME_TOTAL / 3600)) hours, $((($TIME_TOTAL / 60) % 60)) minutes and $(($TIME_TOTAL % 60)) seconds."

# Done

echo -e "Toolchain built into dir: " $DEST
