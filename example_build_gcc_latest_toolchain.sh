#!/bin/bash

# Example non-interactive toolchain build argument list
# Fredrik Hederstierna 2021/2022/2023

INTERACTIVE="No"
TARGET="arm-none-eabi"
WITH_CPU="cortex-m4"
ENABLE_MULTILIB="Y"
PARALLEL_MAKE="Y"
LANGUAGES="c,c++"
BINUTILS_VERSION="2.40"
GCC_VERSION="13.1.0"
NEWLIB_VERSION="4.3.0.20230120"
GDB_VERSION="13.1"
DEST_PATH="/opt/gcc"
DEST_PATH_SUFFIX=""
HARDFLOAT="N"
NANO_LIBS="Y"
STATIC="Y"
LTO="Y"
BUILD_GDB="Y"
BUILD_GDB_SIMULATOR="N"
BUILD_RPM="N"
BUILD_RPM_REPACKAGE_GZIP="N"
SUDO_INSTALL="Y"
APPLY_PATCH="Y"
DOWNLOAD_GNU_SERVER="http://ftp.gnu.org/gnu"
DOWNLOAD_NEWLIB_SERVER="http://sourceware.org/pub/newlib"
WGET_HTTP_PROXY_EXTRA=""
#WGET_HTTP_PROXY_EXTRA="-e use_proxy=yes -e http_proxy=xxx.xxx.xxx.xxx:yyyy"
WGET_FTP_PROXY_EXTRA=""
#WGET_FTP_PROXY_EXTRA="-e use_proxy=yes -e ftp_proxy=xxx.xxx.xxx.xxx:yyyy"

source ./gnu_toolchain_build_buddy.sh
