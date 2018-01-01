#!/bin/bash
# Example non-interactive toolchain build argument list
ARGS=""
ARGS+=' 'INTERACTIVE="No"
ARGS+=' 'TARGET="arm-none-eabi"
ARGS+=' 'LANGUAGES="c,c++"
ARGS+=' 'BINUTILS_VERSION="2.29.1"
ARGS+=' 'GCC_VERSION="7.2.0"
ARGS+=' 'NEWLIB_VERSION="2.5.0"
ARGS+=' 'GDB_VERSION="8.0.1"
ARGS+=' 'DEST_PATH="/usr/local/gcc"
ARGS+=' 'DEST_PATH_SUFFIX=""
ARGS+=' 'HARDFLOAT="Y"
ARGS+=' 'BUILD_GDB="Y"
ARGS+=' 'APPLY_PATCH="Y"
ARGS+=' 'DOWNLOAD_GNU_SERVER="http://ftp.gnu.org/gnu"
ARGS+=' 'DOWNLOAD_NEWLIB_SERVER="ftp://sourceware.org/pub/newlib"
ARGS+=' 'WGET_HTTP_PROXY_EXTRA=""
ARGS+=' 'WGET_FTP_PROXY_EXTRA=""
echo "Args: " ${ARGS}
sudo ./gnu_toolchain_build_buddy.sh ${ARGS}
