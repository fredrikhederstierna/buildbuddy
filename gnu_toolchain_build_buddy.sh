#!/bin/bash

VERSION="1.4.1"

# GNU Toolchain Build Buddy
#
# Simple wizard to download, configure and build the GNU toolchain
# targeting especially bare-metal cross-compilers for embedded systems.
#
# Written by Fredrik Hederstierna 2015/2016/2017/2018/2019/2020/2021/2022
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
# 1.1    Added possibility to add command line arguments for defaults
#        and to disable interactive mode.
# 1.2    Added parallel execution when extracting compressed sources.
#        Added optional sudo execution for make install.
# 1.2.1  Added optional multilib and cpu config.
# 1.2.2  Added versions of binutils and newlib on dest path.
# 1.3    Added RPM package support. Added static build support.
#        Removed newlib FTP dependency. Added gitignore for archives.
#        Thanks to Par L for contrib!
# 1.3.1  Fixed regexp for interactive to accept any word starting with y/Y/n/N.
#        Thanks to Magnus L for testing and ideas!
# 1.3.2  Made parallel make optional.
# 1.3.3  Added write to a build config file.
# 1.3.4  Fixed that deb-package will use gzip, and not xz at default internal
#        compression method, since some other tools might have problems with xz.
# 1.3.5  Removed unnecessary BINUTILS is built inside GDB.
# 1.3.6  Added option to build GDB simulator.
# 1.3.7  Added install dependency shell script, including all packages below.
# 1.3.8  Removed build_id links in the rpmbuild packages.
# 1.3.9  Build RPM in current folder, if no write access in user root folder.
# 1.4.0  Added new option NANO_LIBS to be able to build the built-in compiler
#        libraries for newlib libc and libstdc++ optimized for small size.
#        For example has the nano-version of libstdc++ no exception support.
# 1.4.1  Adding fix for LTO (Link Time Optimization) doesn't allow static libs.
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
#   xz-utils
#   bison
#   flex
# From GDB 9.3 also might use
#   libipt-dev
#   libbabeltrace-ctf-dev
#
# From GCC 5.3 also this seems needed:
#   libisl-dev
#
# If using rpm build also needed:
#   rpm
#   alien

# BUGS:
# Binutils 2.25.1 assembler does not support 'cortex-m7' cpu option.
# https://bugs.archlinux.org/task/46951
#
# TODO:
# * Add more targets like avr, mips, msp430, i386 etc.
#

# Set shell to exit if error (to debug and dump output use -ex)

set -e

# Setup defaults

INTERACTIVE=${INTERACTIVE:-"Y"}

TARGET_DEFAULT=${TARGET_DEFAULT:-arm-none-eabi}
LANGUAGES_DEFAULT=${LANGUAGES_DEFAULT:-c,c++}

BINUTILS_VERSION_DEFAULT=${BINUTILS_VERSION_DEFAULT:-2.29.1}
GCC_VERSION_DEFAULT=${GCC_VERSION_DEFAULT:-7.2.0}
NEWLIB_VERSION_DEFAULT=${NEWLIB_VERSION_DEFAULT:-2.5.0}
GDB_VERSION_DEFAULT=${GDB_VERSION_DEFAULT:-8.0.1}

DEST_PATH_DEFAULT=${DEST_PATH_DEFAULT:-"/usr/local/gcc"}
DEST_PATH_SUFFIX_DEFAULT=${DEST_PATH_SUFFIX_DEFAULT:-""}

HARDFLOAT_DEFAULT=${HARDFLOAT_DEFAULT:-"Y"}
NANO_LIBS_DEFAULT=${NANO_LIBS_DEFAULT:-"Y"}
STATIC_DEFAULT=${STATIC_DEFAULT:-"N"}
LTO_DEFAULT=${LTO_DEFAULT:-"Y"}
BUILD_GDB_DEFAULT=${BUILD_GDB_DEFAULT:-"Y"}
BUILD_GDB_SIMULATOR_DEFAULT=${BUILD_GDB_SIMULATOR_DEFAULT:-"Y"}
BUILD_RPM_DEFAULT=${BUILD_RPM_DEFAULT:-"N"}
BUILD_RPM_REPACKAGE_GZIP_DEFAULT=${BUILD_RPM_REPACKAGE_GZIP_DEFAULT:-"N"}
SUDO_INSTALL_DEFAULT=${SUDO_INSTALL_DEFAULT:-"Y"}
APPLY_PATCH_DEFAULT=${APPLY_PATCH_DEFAULT:-"Y"}

DOWNLOAD_GNU_SERVER=${DOWNLOAD_GNU_SERVER:-"http://ftp.gnu.org/gnu"}
DOWNLOAD_NEWLIB_SERVER=${DOWNLOAD_NEWLIB_SERVER:-"http://sourceware.org/pub/newlib"}

# Extra proxy settings if needed for wget
# format: WGET_HTTP_PROXY_EXTRA="-e use_proxy=yes -e http_proxy=127.0.0.1:8080"
# format: WGET_FTP_PROXY_EXTRA="-e use_proxy=yes -e ftp_proxy=127.0.0.1:8080"

WGET_HTTP_PROXY_EXTRA=${WGET_HTTP_PROXY_EXTRA:-""}
WGET_FTP_PROXY_EXTRA=${WGET_FTP_PROXY_EXTRA:-""}

# Get user input what to build

printf "GNU Toolchain BuildBuddy version $VERSION\n"
printf "HTTP proxy for wget: $WGET_HTTP_PROXY_EXTRA\n"
printf "FTP proxy for wget:  $WGET_FTP_PROXY_EXTRA\n"
printf "Entering information for requested build:\n"
if [[ $INTERACTIVE =~ ^[Yy].*$ ]]
then
  INTERACTIVE="Yes"
else
  INTERACTIVE="No"
fi
echo -e "Interactive: $INTERACTIVE"

# Choose target

if [[ $INTERACTIVE == "Yes" ]]
then
  read -p "Please enter toolchain target [$TARGET_DEFAULT]: " TARGET
fi
TARGET="${TARGET:-$TARGET_DEFAULT}"
echo -e "Toolchain target: $TARGET"

# Choose languages

if [[ $INTERACTIVE == "Yes" ]]
then
  read -p "Please enter languages to build [$LANGUAGES_DEFAULT]: " LANGUAGES
fi
LANGUAGES="${LANGUAGES:-$LANGUAGES_DEFAULT}"
echo -e "Languages: $LANGUAGES"

# Build GDB?

printf "Should GDB be built? [$BUILD_GDB_DEFAULT]:"
if [[ $INTERACTIVE == "Yes" ]]
then
  read -r -n1 -d '' BUILD_GDB
fi
if [[ $BUILD_GDB != "" ]]
then
  printf "\n"
fi
BUILD_GDB="${BUILD_GDB:-$BUILD_GDB_DEFAULT}"
if [[ $BUILD_GDB =~ ^[Yy].*$ ]]
then
  BUILD_GDB="Yes"
else
  BUILD_GDB="No"
fi
echo -e "Build GDB: $BUILD_GDB"

# Build GDB simulator?

printf "Should GDB Simulator be built? [$BUILD_GDB_SIMULATOR_DEFAULT]:"
if [[ $INTERACTIVE == "Yes" ]]
then
  read -r -n1 -d '' BUILD_GDB_SIMULATOR
fi
if [[ $BUILD_GDB_SIMULATOR != "" ]]
then
  printf "\n"
fi
BUILD_GDB_SIMULATOR="${BUILD_GDB_SIMULATOR:-$BUILD_GDB_SIMULATOR_DEFAULT}"
if [[ $BUILD_GDB_SIMULATOR =~ ^[Yy].*$ ]]
then
  BUILD_GDB_SIMULATOR="Yes"
else
  BUILD_GDB_SIMULATOR="No"
fi
echo -e "Build GDB Simulator: $BUILD_GDB_SIMULATOR"

# Build RPM?

printf "Should RPM be built? [$BUILD_RPM_DEFAULT]:"
if [[ $INTERACTIVE == "Yes" ]]
then
  read -r -n1 -d '' BUILD_RPM
fi
if [[ $BUILD_RPM != "" ]]
then
  printf "\n"
fi
BUILD_RPM="${BUILD_RPM:-$BUILD_RPM_DEFAULT}"
if [[ $BUILD_RPM =~ ^[Yy].*$ ]]
then
  BUILD_RPM="Yes"
else
  BUILD_RPM="No"
fi
echo -e "Build RPM: $BUILD_RPM"

# Repackage RPM/DEB to gzip?

printf "Should RPM use gzip(not xz)? [$BUILD_RPM_REPACKAGE_GZIP_DEFAULT]:"
if [[ $INTERACTIVE == "Yes" ]]
then
  read -r -n1 -d '' BUILD_RPM_REPACKAGE_GZIP
fi
if [[ $BUILD_RPM_REPACKAGE_GZIP != "" ]]
then
  printf "\n"
fi
BUILD_RPM_REPACKAGE_GZIP="${BUILD_RPM_REPACKAGE_GZIP:-$BUILD_RPM_REPACKAGE_GZIP_DEFAULT}"
if [[ $BUILD_RPM_REPACKAGE_GZIP =~ ^[Yy].*$ ]]
then
  BUILD_RPM_REPACKAGE_GZIP="Yes"
else
  BUILD_RPM_REPACKAGE_GZIP="No"
fi
echo -e "Build RPM use gzip: $BUILD_RPM_REPACKAGE_GZIP"

# Superuser execution of make install

printf "Should make install be executed with sudo? [$SUDO_INSTALL_DEFAULT]:"
if [[ $INTERACTIVE == "Yes" ]]
then
  read -r -n1 -d '' SUDO_INSTALL
fi
if [[ $SUDO_INSTALL != "" ]]
then
  printf "\n"
fi
SUDO_INSTALL="${SUDO_INSTALL:-$SUDO_INSTALL_DEFAULT}"
if [[ $SUDO_INSTALL =~ ^[Yy].*$ ]]
then
  SUDO_INSTALL="Yes"
  SUDO="sudo"
else
  SUDO_INSTALL="No"
  SUDO=""
fi
echo -e "Make install with sudo: $SUDO_INSTALL"

# Check multilib

ENABLE_MULTILIB=${ENABLE_MULTILIB:-"Y"}
if [[ $ENABLE_MULTILIB =~ ^[Yy].*$ ]]
then
  MULTILIB="--enable-multilib"
else
  MULTILIB="--disable-multilib"
fi
echo -e "Multilib: $ENABLE_MULTILIB"

# Check parallel make

# Get max CPU cores to parallelize make
# If this causes problems, just set PARALLEL_EXE=""
# Sometimes I've observed that gcc-build just stops too early without error

NPROCESS=`getconf _NPROCESSORS_ONLN`
NTHREAD=$(($NPROCESS*2))

PARALLEL_MAKE=${PARALLEL_MAKE:-"Y"}
if [[ $PARALLEL_MAKE =~ ^[Yy].*$ ]]
then
  PARALLEL_MAKE="Yes"
  PARALLEL_EXE="--jobs=$NTHREAD --max-load=$NTHREAD"
else
  PARALLEL_MAKE="No"
  PARALLEL_EXE=""
fi
echo -e "Parallel make: $PARALLEL_MAKE"

# Set some script generated local variables to empty

BINUTILS_ARCH_SUFFIX=""
GCC_ARCH_SUFFIX=""
GDB_ARCH_SUFFIX=""

# Choose tool versions to build

if [[ $INTERACTIVE == "Yes" ]]
then
  read -p "Please enter Binutils version [$BINUTILS_VERSION_DEFAULT]: " BINUTILS_VERSION
fi
BINUTILS_VERSION="${BINUTILS_VERSION:-$BINUTILS_VERSION_DEFAULT}"
echo -e "Binutils version: $BINUTILS_VERSION"

# Use version sort to get lowest BINUTILS version
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

if [[ $INTERACTIVE == "Yes" ]]
then
  read -p "Please enter GCC version [$GCC_VERSION_DEFAULT]: " GCC_VERSION
fi
GCC_VERSION="${GCC_VERSION:-$GCC_VERSION_DEFAULT}"
echo -e "GCC version: $GCC_VERSION"

# Use version sort to get lowest GCC version
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

if [[ $INTERACTIVE == "Yes" ]]
then
  read -p "Please enter Newlib version [$NEWLIB_VERSION_DEFAULT]: " NEWLIB_VERSION
fi
NEWLIB_VERSION="${NEWLIB_VERSION:-$NEWLIB_VERSION_DEFAULT}"
echo -e "Newlib version: $NEWLIB_VERSION"

if [[ $BUILD_GDB == "Yes" ]]
then
  if [[ $INTERACTIVE == "Yes" ]]
  then
    read -p "Please enter GDB version [$GDB_VERSION_DEFAULT]: " GDB_VERSION
  fi
  GDB_VERSION="${GDB_VERSION:-$GDB_VERSION_DEFAULT}"
  echo -e "GDB version: $GDB_VERSION"

  # Use version sort to get lowest GDB version
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

if [[ $INTERACTIVE == "Yes" ]]
then
  read -p "Please enter path where to build toolchain [$DEST_PATH_DEFAULT]: " DEST_PATH
fi
DEST_PATH="${DEST_PATH:-$DEST_PATH_DEFAULT}"

if [[ $INTERACTIVE == "Yes" ]]
then
  read -p "Extra path suffix [$DEST_PATH_SUFFIX_DEFAULT]: " DEST_PATH_SUFFIX
fi
DEST_PATH_SUFFIX="${DEST_PATH_SUFFIX:-$DEST_PATH_SUFFIX_DEFAULT}"

# Set float config

printf "Should GCC be built with hard float? [$HARDFLOAT_DEFAULT]: "
if [[ $INTERACTIVE == "Yes" ]]
then
  read -r -n1 -d '' HARDFLOAT
fi
if [[ $HARDFLOAT != "" ]]
then
  printf "\n"
fi
HARDFLOAT="${HARDFLOAT:-$HARDFLOAT_DEFAULT}"
if [[ $HARDFLOAT =~ ^[Yy].*$ ]]
then
  HARDFLOAT="Yes"
  FLOAT="hardfloat"
else
  HARDFLOAT="No"
  FLOAT="softfloat"
fi
echo -e "\nUse Hardfloat: $HARDFLOAT"

# Set nano libs config

printf "Should GCC be built with using libs optimized for size? [$NANO_LIBS_DEFAULT]: "
if [[ $INTERACTIVE == "Yes" ]]
then
  read -r -n1 -d '' NANO_LIBS
fi
if [[ $NANO_LIBS != "" ]]
then
  printf "\n"
fi
NANO_LIBS="${NANO_LIBS:-$NANO_LIBS_DEFAULT}"
if [[ $NANO_LIBS =~ ^[Yy].*$ ]]
then
  NANO_LIBS="Yes"
else
  NANO_LIBS="No"
fi
echo -e "\nUse libs optimized for size: $NANO_LIBS"

# Set static config

printf "Should GCC be built static? [$STATIC_DEFAULT]: "
if [[ $INTERACTIVE == "Yes" ]]
then
  read -r -n1 -d '' STATIC
fi
if [[ $STATIC != "" ]]
then
  printf "\n"
fi
STATIC="${STATIC:-$STATIC_DEFAULT}"
if [[ $STATIC =~ ^[Yy].*$ ]]
then
  STATIC="Yes"
  STATIC_COMPILE_ARG="-static"
  GCC_CONFIG_STATIC="--disable-shared --disable-host-shared"
else
  STATIC="No"
  STATIC_COMPILE_ARG=""
  GCC_CONFIG_STATIC=""
fi
echo -e "\nUse Static: $STATIC"

# Set LTO config

printf "Should GCC be built with using libs support for LTO (Link Time Optimization)? [$LTO_DEFAULT]: "
if [[ $INTERACTIVE == "Yes" ]]
then
  read -r -n1 -d '' LTO
fi
if [[ $LTO != "" ]]
then
  printf "\n"
fi
LTO="${LTO:-$LTO_DEFAULT}"
if [[ $LTO =~ ^[Yy].*$ ]]
then
  LTO="Yes"
else
  LTO="No"
fi
echo -e "\nUse libs support for LTO: $LTO"

# Set resulting destination path
DEST="$DEST_PATH/$TARGET-toolchain-gcc-$GCC_VERSION-binutils-$BINUTILS_VERSION-newlib-$NEWLIB_VERSION-$FLOAT$DEST_PATH_SUFFIX"
echo -e "Build toolchain into path: $DEST"

# Special handling if building RPM
if [[ $BUILD_RPM == "Yes" ]]
then
  PACKAGE_NAME="$TARGET-toolchain-gcc-$GCC_VERSION-binutils-$BINUTILS_VERSION-newlib-$NEWLIB_VERSION-$FLOAT$DEST_PATH_SUFFIX"
  DEST="$PWD$DEST"
fi

# Patches

printf "Apply patches? [$APPLY_PATCH_DEFAULT]: "
if [[ $INTERACTIVE == "Yes" ]]
then
  read -r -n1 -d '' APPLY_PATCH
fi
if [[ $APPLY_PATCH != "" ]]
then
  printf "\n"
fi
APPLY_PATCH="${APPLY_PATCH:-$APPLY_PATCH_DEFAULT}"
if [[ $APPLY_PATCH =~ ^[Yy].*$ ]]
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

# Check if GDB simulator should be built

if [[ $BUILD_GDB_SIMULATOR == "Yes" ]]
then
  EXTRA_GDB_CONFIGURE_OPTS="--enable-sim"
fi

# Set rwx access

umask 022

# Write config made

BUILD_CONFIG_FILENAME="build.cfg"
echo "#!/bin/bash" > $BUILD_CONFIG_FILENAME
echo "# Buildbuddy version $VERSION." >> $BUILD_CONFIG_FILENAME
echo "# Auto-generated build config." >> $BUILD_CONFIG_FILENAME
echo "INTERACTIVE=\"$INTERACTIVE\""   >> $BUILD_CONFIG_FILENAME
echo "TARGET=\"$TARGET\""             >> $BUILD_CONFIG_FILENAME
echo "WITH_CPU=\"$WITH_CPU\""         >> $BUILD_CONFIG_FILENAME
echo "ENABLE_MULTILIB=\"$ENABLE_MULTILIB\""   >> $BUILD_CONFIG_FILENAME
echo "PARALLEL_MAKE=\"$PARALLEL_MAKE\""       >> $BUILD_CONFIG_FILENAME
echo "LANGUAGES=\"$LANGUAGES\""               >> $BUILD_CONFIG_FILENAME
echo "BINUTILS_VERSION=\"$BINUTILS_VERSION\"" >> $BUILD_CONFIG_FILENAME
echo "GCC_VERSION=\"$GCC_VERSION\""           >> $BUILD_CONFIG_FILENAME
echo "NEWLIB_VERSION=\"$NEWLIB_VERSION\""     >> $BUILD_CONFIG_FILENAME
echo "GDB_VERSION=\"$GDB_VERSION\""           >> $BUILD_CONFIG_FILENAME
echo "DEST_PATH=\"$DEST_PATH\""               >> $BUILD_CONFIG_FILENAME
echo "DEST_PATH_SUFFIX=\"$DEST_PATH_SUFFIX\"" >> $BUILD_CONFIG_FILENAME
echo "HARDFLOAT=\"$HARDFLOAT\"" >> $BUILD_CONFIG_FILENAME
echo "NANO_LIBS=\"$NANO_LIBS\"" >> $BUILD_CONFIG_FILENAME
echo "STATIC=\"$STATIC\""       >> $BUILD_CONFIG_FILENAME
echo "LTO=\"$LTO\""             >> $BUILD_CONFIG_FILENAME
echo "BUILD_GDB=\"$BUILD_GDB\"" >> $BUILD_CONFIG_FILENAME
echo "BUILD_GDB_SIMULATOR=\"$BUILD_GDB_SIMULATOR\"" >> $BUILD_CONFIG_FILENAME
echo "BUILD_RPM=\"$BUILD_RPM\"" >> $BUILD_CONFIG_FILENAME
echo "BUILD_RPM_REPACKAGE_GZIP=\"$BUILD_RPM_REPACKAGE_GZIP\"" >> $BUILD_CONFIG_FILENAME
echo "SUDO_INSTALL=\"$SUDO_INSTALL\"" >> $BUILD_CONFIG_FILENAME
echo "APPLY_PATCH=\"$APPLY_PATCH\""   >> $BUILD_CONFIG_FILENAME
echo "DOWNLOAD_GNU_SERVER=\"$DOWNLOAD_GNU_SERVER\""       >> $BUILD_CONFIG_FILENAME
echo "DOWNLOAD_NEWLIB_SERVER=\"$DOWNLOAD_NEWLIB_SERVER\"" >> $BUILD_CONFIG_FILENAME
echo "WGET_HTTP_PROXY_EXTRA=\"$WGET_HTTP_PROXY_EXTRA\"" >> $BUILD_CONFIG_FILENAME
echo "WGET_FTP_PROXY_EXTRA=\"$WGET_FTP_PROXY_EXTRA\""   >> $BUILD_CONFIG_FILENAME
echo "source ./gnu_toolchain_build_buddy.sh"   >> $BUILD_CONFIG_FILENAME

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
  wget $WGET_HTTP_PROXY_EXTRA $DOWNLOAD_NEWLIB_SERVER/$NEWLIB_SRC_FILE
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
  tar xJf "$BINUTILS_SRC_FILE" &
else
  tar xjf "$BINUTILS_SRC_FILE" &
fi

echo -e "Unpacking gcc sources..."
if [[ $GCC_ARCH_SUFFIX == "xz" ]]
then
  tar xJf "$GCC_SRC_FILE" &
else
  tar xjf "$GCC_SRC_FILE" &
fi


echo -e "Unpacking newlib sources..."
tar xzf "$NEWLIB_SRC_FILE" &

if [[ $BUILD_GDB == "Yes" ]]
then
  rm -fr "$GDB_DIR"
  echo -e "Unpacking gdb sources..."
  if [[ $GDB_ARCH_SUFFIX == "xz" ]]
  then
    tar xJf "$GDB_SRC_FILE" &
  else
    tar xjf "$GDB_SRC_FILE" &
  fi
fi

# Wait for parallelized extractions to finish
echo -e "Waiting of unpacking finished..."
for job in `jobs -p`
do
    wait $job
done

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
make $PARALLEL_EXE LDFLAGS="-s $STATIC_COMPILE_ARG" all MAKEINFO=missing
$SUDO make install
TIMESTAMP_BUILD_BINUTILS_END=$SECONDS

# Setup gcc build flags

WITH_OPTS="--with-gnu-as --with-gnu-ld --with-newlib --with-system-zlib"
DISABLE_OPTS="--disable-nls --disable-libssp $GCC_CONFIG_STATIC"
ENABLE_OPTS=""

# Target specific flags

# ARM specific flags, example tune for Cortex-M4(F)

if [[ $TARGET == *"arm"* ]]
then
  TARGET_OPTS="--with-endian=little --disable-interwork"

  # Older gcc-3.4.6 do not use eabi, use arm-elf default abi
  if [[ $TARGET == *"eabi"* ]]
  then
    # If no explicit CPU selected, use cortex-m4 by default for arm-eabi
    WITH_CPU=${WITH_CPU:-"cortex-m4"}
    EXTRA_TARGET_OPTS="$MULTILIB"
    WITH_ABI_OPTS="--with-mode=thumb --with-abi=aapcs --with-cpu=$WITH_CPU"
  else
    # If no explicit CPU selected, use arm7tdmi by default for arm-elf
    WITH_CPU=${WITH_CPU:-"arm7tdmi"}
    EXTRA_TARGET_OPTS="$MULTILIB --enable-targets=arm-elf"
    WITH_ABI_OPTS="--with-cpu=$WITH_CPU"
  fi

  if [[ $HARDFLOAT == "Yes" ]]
  then
    WITH_FLOAT_OPTS="--with-float=hard --with-fpu=fpv4-sp-d16"
  else
    WITH_FLOAT_OPTS="--with-float=soft"
  fi
fi

# Extra optimization options for small size

if [[ $NANO_LIBS == "Yes" ]]
then
  NANO_LIBS_OPTS="--disable-decimal-float --disable-libffi --disable-libgomp --disable-libmudflap --disable-libquadmath --disable-libstdcxx-pch --disable-libstdcxx-verbose --disable-shared --disable-threads --disable-tls --disable-nls --disable-libssp --disable-newlib-supplied-syscalls --disable-newlib-fvwrite-in-streamio --disable-newlib-fseek-optimization --disable-newlib-wide-orient --disable-newlib-unbuf-stream-opt --enable-newlib-reent-small --enable-newlib-global-atexit --enable-newlib-nano-malloc --enable-newlib-nano-formatted-io --enable-lite-exit"
  NANO_LIBS_CFLAGS="-DPREFER_SIZE_OVER_SPEED=1 -Os -ffunction-sections -fdata-sections"
  NANO_LIBS_CXXFLAGS="-DPREFER_SIZE_OVER_SPEED=1 -Os -ffunction-sections -fdata-sections -fno-exceptions -fno-unwind-tables -fno-threadsafe-statics -fno-use-cxa-atexit"
else
  NANO_LIBS_OPTS=""
  NANO_LIBS_CFLAGS="-g -O2 -ffunction-sections -fdata-sections"
  NANO_LIBS_CXXFLAGS="-g -O2 -ffunction-sections -fdata-sections"
fi

# Extra options for LTO (Link Time Optimization)
# GCC target libraries cannot be static compiled if using LTO.

if [[ $LTO == "Yes" ]]
then
  STATIC_COMPILE_ARG=""
  LTO_CFLAGS="-flto -ffat-lto-objects"
  LTO_CXXFLAGS="-flto -ffat-lto-objects"
else
  LTO_CFLAGS=""
  LTO_CXXFLAGS=""
fi

# Build gcc

cd ../gcc
PATH="$DEST/bin:$PATH"
TIMESTAMP_BUILD_GCC_START=$SECONDS
"../../$GCC_DIR/configure" --enable-languages="$LANGUAGES" --target="$TARGET" --prefix="$DEST" $WITH_OPTS $TARGET_OPTS $WITH_ABI_OPTS $WITH_FLOAT_OPTS $DISABLE_OPTS $EXTRA_TARGET_OPTS $ENABLE_OPTS $NANO_LIBS_OPTS
make CFLAGS='-std=gnu89' CFLAGS_FOR_TARGET="$NANO_LIBS_CFLAGS $LTO_CFLAGS" CXXFLAGS="$NANO_LIBS_CXXFLAGS $LTO_CXXFLAGS" CXXFLAGS_FOR_TARGET="$NANO_LIBS_CXXFLAGS $LTO_CXXFLAGS" $PARALLEL_EXE LDFLAGS="-s $STATIC_COMPILE_ARG" all MAKEINFO=missing
make CFLAGS='-std=gnu89' CFLAGS_FOR_TARGET="$NANO_LIBS_CFLAGS $LTO_CFLAGS" CXXFLAGS="$NANO_LIBS_CXXFLAGS $LTO_CXXFLAGS" CXXFLAGS_FOR_TARGET="$NANO_LIBS_CXXFLAGS $LTO_CXXFLAGS" $PARALLEL_EXE LDFLAGS="-s $STATIC_COMPILE_ARG" all-gcc MAKEINFO=missing
$SUDO make install-gcc
$SUDO make install
TIMESTAMP_BUILD_GCC_END=$SECONDS

# Build gdb

if [[ $BUILD_GDB == "Yes" ]]
then
  cd ../gdb
  TIMESTAMP_BUILD_GDB_START=$SECONDS
  "../../$GDB_DIR/configure" --target="$TARGET" --prefix="$DEST" --with-guile=no --disable-binutils --disable-ld --disable-gold --disable-gas --disable-sim --disable-gprof $EXTRA_GDB_CONFIGURE_OPTS --with-separate-debug-dir=/usr/lib/debug
  make $PARALLEL_EXE --print-directory all MAKEINFO=true
  $SUDO make install
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
echo -e "Build config written to file: " $BUILD_CONFIG_FILENAME

# Build RPM if requested

if [[ $BUILD_RPM == "Yes" ]]
then
  echo -e "Building the RPM and DEB packages..."
  rm -rf /tmp/RPM-BUILDROOT/$PACKAGE_NAME
  mkdir -p rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
  rpmbuild --define "name $PACKAGE_NAME" --define "deploy_dir $PWD/$DEST_PATH" --define "os_install_dir $DEST_PATH" --define "_topdir $PWD/rpmbuild" --buildroot="/tmp/RPM-BUILDROOT/$PACKAGE_NAME" --nocheck -bb rpm.spec
  echo -e "List content compression of the RPM package:"
  rpm -qp --qf '%{PAYLOADCOMPRESSOR}\n' x86_64/$PACKAGE_NAME-1.0-1.x86_64.rpm
  echo -e "Building the DEB package using default compression..."
  fakeroot alien --to-deb --fixperms -k x86_64/$PACKAGE_NAME-1.0-1.x86_64.rpm
  echo -e "List contents of the DEB file:"
  ar t "$PACKAGE_NAME"_1.0-1_amd64.deb
  if [[ $BUILD_RPM_REPACKAGE_GZIP == "Yes" ]]
  then
    echo -e "Repackaging DEB file and force compression to gzip (not xz)..."
    dpkg-deb -R "$PACKAGE_NAME"_1.0-1_amd64.deb tmp
    rm "$PACKAGE_NAME"_1.0-1_amd64.deb
    fakeroot dpkg-deb -Zgzip -b tmp "$PACKAGE_NAME"_1.0-1_amd64.deb
    rm -rf tmp
    echo -e "List contents of the repackaged DEB file:"
    ar t "$PACKAGE_NAME"_1.0-1_amd64.deb
  fi
fi
