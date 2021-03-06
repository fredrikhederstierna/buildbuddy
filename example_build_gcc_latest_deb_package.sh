#!/bin/bash

# Example non-interactive toolchain build argument list
# Fredrik Hederstierna 2019

INTERACTIVE="No"
TARGET="arm-none-eabi"
WITH_CPU="cortex-m4"
ENABLE_MULTILIB="Y"
PARALLEL_MAKE="Y"
LANGUAGES="c"
BINUTILS_VERSION="2.33.1"
GCC_VERSION="10.1.0"
NEWLIB_VERSION="3.3.0"
GDB_VERSION="9.1"
DEST_PATH="/opt/gcc"
DEST_PATH_SUFFIX="rpm"
HARDFLOAT="N"
STATIC="Y"
BUILD_GDB="N"
BUILD_RPM="Y"
BUILD_RPM_REPACKAGE_GZIP="Y"
SUDO_INSTALL="Y"
APPLY_PATCH="Y"
DOWNLOAD_GNU_SERVER="http://ftp.gnu.org/gnu"
DOWNLOAD_NEWLIB_SERVER="http://sourceware.org/pub/newlib"
WGET_HTTP_PROXY_EXTRA=""
#WGET_HTTP_PROXY_EXTRA="-e use_proxy=yes -e http_proxy=xxx.xxx.xxx.xxx:yyyy"
WGET_FTP_PROXY_EXTRA=""
#WGET_FTP_PROXY_EXTRA="-e use_proxy=yes -e ftp_proxy=xxx.xxx.xxx.xxx:yyyy"

source ./gnu_toolchain_build_buddy.sh
