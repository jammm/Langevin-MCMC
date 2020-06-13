FROM ubuntu:18.04

MAINTAINER aaryaman.vasishta@gmail.com

### headless X server dependencies
RUN apt-get update \
    && apt-get install -y \
    libx11-dev \
    libxxf86vm-dev \
    x11-xserver-utils \
    x11proto-xf86vidmode-dev \
    x11vnc \
    xpra \
    xserver-xorg-video-dummy \
    software-properties-common \
    && apt-get clean \
    && apt-get autoclean \
    && apt-get autoremove

### dpt specific dependencies

RUN apt-get update \
    && apt-get install -y \
    git \
    build-essential \
    wget \
    xorg-dev \
    cmake \
    libassimp-dev \
    libglew-dev \
    libglfw3-dev \
    libtbb-dev alien dpkg-dev debhelper \
    freeglut3-dev \
    libxmu-dev libxi-dev \
    libopenimageio-dev \
    libboost-system-dev \
    && apt-get clean \
    && apt-get autoclean \
    && apt-get autoremove

################# INSTALL ISPC (taken from ispc Dockerfile. I might as well use ISPC as the base image but they use ubuntu 16.04, so...)
# Packages required to build ISPC and Clang.
RUN apt-get -y update && apt-get install -y wget build-essential vim gcc g++ git subversion python3 m4 bison flex zlib1g-dev ncurses-dev libtinfo-dev libc6-dev-i386 && \
    rm -rf /var/lib/apt/lists/*

# Download and install required version of cmake (3.13) for ISPC build
RUN wget https://github.com/Kitware/CMake/releases/download/v3.13.5/cmake-3.13.5-Linux-x86_64.sh && mkdir /opt/cmake && sh cmake-3.13.5-Linux-x86_64.sh --prefix=/opt/cmake --skip-license && \
    ln -s /opt/cmake/bin/cmake /usr/local/bin/cmake && rm cmake-3.13.5-Linux-x86_64.sh

WORKDIR /usr/local/src

# Fork ispc on github and clone *your* fork.
RUN git clone https://github.com/ispc/ispc.git

# This is home for Clang builds
RUN mkdir /usr/local/src/llvm

ENV ISPC_HOME=/usr/local/src/ispc
ENV LLVM_HOME=/usr/local/src/llvm

WORKDIR /usr/local/src/ispc

# Build Clang with all required patches.
# Pass required LLVM_VERSION with --build-arg LLVM_VERSION=<version>.
# By default 10.0 is used.
# Note self-build options, it's required to build clang and ispc with the same compiler,
# i.e. if clang was built by gcc, you may need to use gcc to build ispc (i.e. run "make gcc"),
# or better do clang selfbuild and use it for ispc build as well (i.e. just "make").
# "rm" are just to keep docker image small.
ARG LLVM_VERSION=10.0

RUN echo "lol"

RUN ./alloy.py -b --version=$LLVM_VERSION --selfbuild --git && \
    rm -rf $LLVM_HOME/build-$LLVM_VERSION $LLVM_HOME/llvm-$LLVM_VERSION $LLVM_HOME/bin-"$LLVM_VERSION"_temp $LLVM_HOME/build-"$LLVM_VERSION"_temp

ENV PATH=/usr/local/src/ispc/bin-10.0/bin:$LLVM_HOME/bin-$LLVM_VERSION/bin:$PATH

RUN ls -al /usr/local/src/llvm/bin-10.0/bin

# Configure ISPC build
RUN mkdir build_$LLVM_VERSION
WORKDIR build_$LLVM_VERSION
RUN cmake ../ -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_INSTALL_PREFIX=/usr/local/src/ispc/bin-$LLVM_VERSION

# Build ISPC
RUN make ispc -j8 && make install
WORKDIR ../
RUN rm -rf build_$LLVM_VERSION

WORKDIR /dpt

ENV RENDERERR 9

RUN git clone https://github.com/jammm/Langevin-MCMC dpt
WORKDIR /dpt/dpt

# Install tup
RUN apt-get update \
    && apt-get install -y \
    libssl-dev \
    libfuse-dev \
    fuse \
    libeigen3-dev=3.3.4-4 \
    && apt-get clean \
    && apt-get autoclean \
    && apt-get autoremove

#RUN git clone git://github.com/gittup/tup.git

#RUN cd tup && ./bootstrap.sh

RUN wget https://github.com/embree/embree/releases/download/v3.6.1/embree-3.6.1.x86_64.rpm.tar.gz
RUN tar -xzf embree-3.6.1.x86_64.rpm.tar.gz

RUN apt-get install alien dpkg-dev debhelper build-essential

RUN alien embree3-lib-3.6.1-1.x86_64.rpm
RUN alien embree3-devel-3.6.1-1.noarch.rpm
 
RUN dpkg -i embree3-lib_3.6.1-2_amd64.deb
RUN dpkg -i embree3-devel_3.6.1-2_all.deb

RUN ldconfig /usr/lib64
ENV DPT_LIBPATH /dpt/dpt/src/bin

# compile dpt
RUN cd src && ../tup/build/tup generate build-once.sh

#RUN git clone https://gitlab.com/libeigen/eigen.git

### configure headless X server
COPY xorg.conf /etc/X11/xorg.conf
ENV DISPLAY :0
