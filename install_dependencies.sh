#!/bin/bash
# Simple script just installing all dependencies needed to build toolchain.
# Warning: this script assumes Yes on installing packages.

# Some packages possibly needed:
sudo apt-get -y -q install libz-dev
sudo apt-get -y -q install libgmp-dev
sudo apt-get -y -q install libmpc-dev
sudo apt-get -y -q install libmpfr-dev
sudo apt-get -y -q install libboost-all-dev
# GDB also might use
sudo apt-get -y -q install texinfo
sudo apt-get -y -q install libncurses-dev
sudo apt-get -y -q install xz-utils
sudo apt-get -y -q install bison
sudo apt-get -y -q install flex
# From GDB 9.3 also might use
sudo apt-get -y -q install libipt-dev
sudo apt-get -y -q install libbabeltrace-ctf-dev
#
# From GCC 5.3 also this seems needed:
sudo apt-get -y -q install libisl-dev
#
# If using rpm build also needed:
sudo apt-get -y -q install rpm
sudo apt-get -y -q install alien
