#!/bin/bash

# script to build the cross-toolchain for the host system, so that we can
# then compile stage2 (HOST lfs, and TGT lfs)
#
# Run this as 'lfs' user from the $LFS/sources directory

BINUTILS=binutils-2.40
tar -xf ${BINUTILS}.tar.xz && cd $BINUTILS && \
mkdir -pv build && cd build  && \
../configure --prefix=$LFS/tools --with-sysroot=$LFS \
                 --target=$LFS_TGT   --disable-nls       \
                 --enable-gprofng=no  --disable-werror && \
make -j12 && make install && cd ../../ && rm -rf $BINUTILS

GCC=gcc-12.2.0
tar -xf ${GCC}.tar.xz && cd $GCC && \
tar -xf ../mpfr-4.2.0.tar.xz && mv -v mpfr-4.2.0 mpfr && \
tar -xf ../gmp-6.2.1.tar.xz && mv -v gmp-6.2.1 gmp && \
tar -xf ../mpc-1.3.1.tar.gz && mv -v mpc-1.3.1 mpc && \
case $(uname -m) in 
  x86_64) 
    sed -e '/m64=/s/lib64/lib/' 
        -i.orig gcc/config/i386/t-linux64 
    ;; 
esac && \
mkdir -v build && cd build && \
../configure                  \
    --target=$LFS_TGT         \
    --prefix=$LFS/tools       \
    --with-glibc-version=2.37 \
    --with-sysroot=$LFS       \
    --with-newlib             \
    --without-headers         \
    --enable-default-pie      \
    --enable-default-ssp      \
    --disable-nls             \
    --disable-shared          \
    --disable-multilib        \
    --disable-threads         \
    --disable-libatomic       \
    --disable-libgomp         \
    --disable-libquadmath     \
    --disable-libssp          \
    --disable-libvtv          \
    --disable-libstdcxx       \
    --enable-languages=c,c++ && \
make -j12 && make install && \
cd .. && \
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h

cd .. && rm -rf $GCC 



LINUX=linux-6.1.11
tar -xf ${LINUX}.tar.xz && cd $LINUX && \
make mrproper && \
make -j12 headers && \
find usr/include -type f ! -name '*.h' -delete && \
cp -rv usr/include $LFS/usr && \
cd .. && rm -rf $LINUX

GLIBC=glibc-2.37
tar -xf ${GLIBC}.tar.xz && cd $GLIBC 
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
esac

patch -Np1 -i ../glibc-2.37-fhs-1.patch

mkdir -v build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2                \
      --with-headers=$LFS/usr/include    \
      libc_cv_slibdir=/usr/lib
make -j12 && make DESTDIR=$LFS install && \
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

# test new toolchain
echo 'int main(){}' | $LFS_TGT-gcc -xc -
readelf -l a.out | grep ld-linux

rm -v a.out

# make headers
$LFS/tools/libexec/gcc/$LFS_TGT/12.2.0/install-tools/mkheaders

# build libstd++
tar -xf $GCC && cd $GCC
mkdir -v build && cd build
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/12.2.0 && \
make -j12 && make DESTDIR=$LFS install && rm -v $LFS/usr/lib/lib{stdc++,stdc++fs,supc++}.la && \
cd ../../ && rm -rf $GCC

