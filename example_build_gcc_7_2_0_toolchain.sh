#!/bin/bash

# Example non-interactive toolchain build argument list
# Fredrik Hederstierna 2018

INTERACTIVE="No"
TARGET="arm-none-eabi"
LANGUAGES="c,c++"
BINUTILS_VERSION="2.29.1"
GCC_VERSION="7.2.0"
NEWLIB_VERSION="2.5.0"
GDB_VERSION="8.0.1"
DEST_PATH="/usr/local/gcc"
DEST_PATH_SUFFIX=""
HARDFLOAT="Y"
BUILD_GDB="Y"
SUDO_INSTALL="Y"
APPLY_PATCH="Y"
DOWNLOAD_GNU_SERVER="http://ftp.gnu.org/gnu"
DOWNLOAD_NEWLIB_SERVER="ftp://sourceware.org/pub/newlib"
WGET_HTTP_PROXY_EXTRA=""
#WGET_HTTP_PROXY_EXTRA="-e use_proxy=yes -e http_proxy=xxx.xxx.xxx.xxx:yyyy"
WGET_FTP_PROXY_EXTRA=""
#WGET_FTP_PROXY_EXTRA="-e use_proxy=yes -e ftp_proxy=xxx.xxx.xxx.xxx:yyyy"

source ./gnu_toolchain_build_buddy.sh
