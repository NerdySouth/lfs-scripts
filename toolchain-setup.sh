#!/bin/bash
# assumes that $LFS/sources exists, and is writable and sticky, and that all the 
# programs in the wget-list-systemd are there. This script should be run as root on 
# the HOST (system used to build LFS). We also assume lfs user already exists 
# since that will be needed to actually build the programs

LFS=/mnt/lfs

# make root owner of the sources directory
chown root:root $LFS/sources/*

# Create limited directory layout for fs 
mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}
for i in bin lib sbin; do
  ln -sv usr/$i $LFS/$i
done

case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac

mkdir -pv $LFS/tools

# give lfs user ownership of source files
chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac


