#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKING_DIR="$SCRIPT_DIR/../.sources"
export PATH="$PATH:/usr/local/bin"

source $SCRIPT_DIR/lib.sh


# cmake
# downloads: http://www.cmake.org/download/

function install_cmake() {
  if [ "$OS" = "centos" ] || [ "$OS" = "ubuntu" ] || [ "$OS" = "darwin" ]; then
    if [[ ! -f cmake-2.8.12.2.tar.gz ]]; then
      log "downloading the cmake source"
      wget http://www.cmake.org/files/v2.8/cmake-2.8.12.2.tar.gz
    fi
    if [[ ! -d cmake-2.8.12.2 ]]; then
      log "unpacking the cmake source"
      tar -xf cmake-2.8.12.2.tar.gz
    fi
    if [[ -f /usr/local/bin/cmake ]]; then
      log "cmake is already installed. skipping."
    else
      log "building cmake"
      pushd cmake-2.8.12.2 > /dev/null
      CC=clang CXX=clang++ ./configure
      make
      sudo make install
      popd
    fi
  fi
}

function install_thrift() {
  if [[ ! -f /usr/local/lib/libthrift.a ]]; then
    if [[ ! -f 0.9.1.tar.gz ]]; then
      wget https://github.com/apache/thrift/archive/0.9.1.tar.gz
    fi
    if [[ ! -d thrift-0.9.1 ]]; then
      tar -xf 0.9.1.tar.gz
    fi
    pushd thrift-0.9.1
    ./bootstrap.sh
    ./configure --with-ruby=no --with-go=no
    make
    sudo make install
    popd
  else
    log "thrift is installed. skipping."
  fi
}

function install_rocksdb() {
  if [[ ! -f /usr/local/lib/librocksdb.a ]]; then
    if [[ ! -f rocksdb-3.5.tar.gz ]]; then
      wget https://github.com/facebook/rocksdb/archive/rocksdb-3.5.tar.gz
    fi
    if [[ ! -d rocksdb-rocksdb-3.5 ]]; then
      tar -xf rocksdb-3.5.tar.gz
    fi
    if [ $OS = "ubuntu" ] || [ $OS = "centos" ]; then
      if [[ ! -f rocksdb-rocksdb-3.5/librocksdb.a ]]; then
        pushd rocksdb-rocksdb-3.5
        make static_lib CFLAGS="-I /usr/include/clang/3.4/include"
        popd
      fi
      sudo cp rocksdb-rocksdb-3.5/librocksdb.a /usr/local/lib
      sudo cp -R rocksdb-rocksdb-3.5/include/rocksdb /usr/local/include
    elif [[ $OS = "darwin" ]]; then
      if [[ ! -f rocksdb-rocksdb-3.5/librocksdb.a ]]; then
        pushd rocksdb-rocksdb-3.5
        make static_lib
        popd
      fi
      sudo cp rocksdb-rocksdb-3.5/librocksdb.a /usr/local/lib
      sudo cp -R rocksdb-rocksdb-3.5/include/rocksdb /usr/local/include
    fi
  else
    log "rocksdb already installed. skipping."
  fi
}

function install_boost() {
  if [[ ! -f /usr/local/lib/libboost_thread.a ]]; then
    if [[ ! -f boost_1_55_0.tar.gz ]]; then
      wget -O boost_1_55_0.tar.gz http://sourceforge.net/projects/boost/files/boost/1.55.0/boost_1_55_0.tar.gz/download
    else
      log "boost source is already downloaded. skipping."
    fi
    if [[ ! -d boost_1_55_0 ]]; then
      tar -xf boost_1_55_0.tar.gz
    fi
    pushd boost_1_55_0
    ./bootstrap.sh
    n=`cat /proc/cpuinfo | grep "cpu cores" | uniq | awk '{print $NF}'`
    sudo ./b2 --with=all -j $n toolset=clang install
    sudo ldconfig
    popd
  else
    log "boost library is already installed. skipping."
  fi
}

function install_gflags() {
  if [[ ! -f /usr/local/lib/libgflags.a ]]; then
    if [[ ! -f v2.1.1.tar.gz ]]; then
      wget https://github.com/schuhschuh/gflags/archive/v2.1.1.tar.gz
    else
      log "gflags source is already downloaded. skipping."
    fi
    if [[ ! -d gflags-2.1.1 ]]; then
      tar -xf v2.1.1.tar.gz
    fi
    pushd gflags-2.1.1
    cmake -DCMAKE_CXX_FLAGS=-fPIC -DGFLAGS_NAMESPACE:STRING=google .
    make
    sudo make install
    popd
  else
    log "gflags library is already installed. skipping."
  fi
}

function install_glog() {
  if [[ ! -d /usr/local/include/glog ]]; then
    if [[ ! -f glog-0.3.3.tar.gz ]]; then
      wget https://google-glog.googlecode.com/files/glog-0.3.3.tar.gz
    else
      log "glog source is already downloaded. skipping."
    fi
    if [[ ! -d glog-0.3.3 ]]; then
      tar -xf glog-0.3.3.tar.gz
    fi
    pushd glog-0.3.3
    ./configure CXXFLAGS="-DGFLAGS_NAMESPACE=google"
    make
    sudo make install
    popd
  else
    log "glog is already installed. skipping."
  fi
}

function package() {
  if [[ $OS = "ubuntu" ]]; then
    if dpkg --get-selections | grep --quiet $1; then
      log "$1 is already installed. skipping."
    else
      sudo apt-get install $@ -y
    fi
  elif [[ $OS = "centos" ]]; then
    if rpm -qa | grep --quiet $1; then
      log "$1 is already installed. skipping."
    else
      sudo yum install $@ -y
    fi
  elif [[ $OS = "darwin" ]]; then
    if brew list | grep --quiet $1; then
      log "$1 is already installed. skipping."
    else
      brew install $@ || brew upgrade $@
    fi
  fi
}

function main() {
  platform OS

  mkdir -p $WORKING_DIR
  cd $WORKING_DIR

  if [[ $OS = "centos" ]]; then
    log "detected centos"
  elif [[ $OS = "ubuntu" ]]; then
    log "detected ubuntu"
    DISTRO=`cat /etc/*-release | grep DISTRIB_CODENAME | awk '{split($0,bits,"="); print bits[2]}'`
  elif [[ $OS = "darwin" ]]; then
    log "detected mac os x"
  else
    fatal "could not detect the current operating system. exiting."
  fi

  threads THREADS

  if [[ $OS = "ubuntu" ]]; then

    if [[ $DISTRO = "precise" ]]; then
      sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    fi
    sudo apt-get update

    package git
    package unzip
    package build-essential
    package libtool
    package autoconf
    package automake
    package pkg-config
    package libssl-dev
    package liblzma-dev
    package bison
    package flex
    package python-pip
    package python-dev
    package libbz2-dev
    package devscripts
    package debhelper
    package clang-3.4
    package clang-format-3.4
    set_cc clang
    set_cxx clang++
    if [[ $DISTRO = "precise" ]]; then
      package gcc-4.7
      package g++-4.7
      sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.7 100 --slave /usr/bin/g++ g++ /usr/bin/g++-4.7
      install_boost
      install_cmake
    else
      package cmake
      package libboost1.55-all-dev
    fi
    if [[ $DISTRO = "precise" ]]; then
      package libunwind7-dev
    fi
    if [[ $DISTRO = "trusty" ]]; then
      package libunwind8-dev
    fi
    if [[ $DISTRO = "precise" ]]; then
      install_gflags
    else
      package libgoogle-glog-dev
    fi

    if [[ $DISTRO = "precise" ]]; then
      install_glog
    else
      package libgoogle-glog-dev
    fi
    package libsnappy-dev
    package libbz2-dev
    package libreadline-dev
    if [[ $DISTRO = "precise" ]]; then
      package libproc-dev
    else
      package libprocps3-dev
    fi
    install_thrift
    install_rocksdb

  elif [[ $OS = "centos" ]]; then
    sudo yum update -y
    package git-all
    package unzip
    package xz

  elif [[ $OS = "darwin" ]]; then
    if [[ ! -f "/usr/local/bin/brew" ]]; then
      fatal "could not find homebrew. please install it from http://brew.sh/"
    fi
    if brew list | grep --quiet wget; then
      log "wget is already installed. skipping"
    else
      brew install wget
    fi
    package cmake
    package boost --c++11
    package gflags
    package glog
    package snappy
    package readline
    package thrift
    package lz4
    install_rocksdb
  fi

  cd $SCRIPT_DIR/../
  sudo pip install -r requirements.txt
  git submodule init
  git submodule update
}

main
