#!/bin/sh
set -e
apt update -y &&  apt upgrade -y && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata
apt install curl wget git subversion build-essential autoconf automake libtool libncurses5 libncurses5-dev make libjpeg-dev libtool libtool-bin libsqlite3-dev libpcre3-dev libspeexdsp-dev libldns-dev libedit-dev yasm liblua5.2-dev libopus-dev cmake libtiff-dev  libcodec2-dev libcodec2-dev portaudio19-dev libmagickcore-dev libmp3lame-dev libmpg123-dev libshout3-dev libvlc-dev libpq-dev libmariadb-dev libldap2-dev erlang librabbitmq-dev libsmpp34-dev libyaml-dev libmongoc-dev libopencv-dev  libmemcached-dev libavformat-dev  libh2o-dev libsoundtouch-dev libhiredis-dev libopus-dev  autoconf automake devscripts gawk gettext libcurl4-openssl-dev libdb-dev libedit-dev libgdbm-dev libldns-dev libncurses5-dev libopus-dev libopus-ocaml libpcre3-dev libperl-dev libpq-dev libspeex-dev libspeexdsp-dev libssl-dev libtiff5-dev libtool libtool-bin libvorbis0a libogg0 libsqlite3-dev libogg-dev libvorbis-dev portaudio19-dev libshout3-dev libmpg123-dev libmp3lame-dev yasm libbsd-dev flite flite1-dev libflite1 liblua5.2-0 liblua5.2-dev lua5.2 luarocks libsndfile-dev -y
apt install gcc-10 g++-10 cpp-10 -y && ln -s /usr/bin/gcc-10 /usr/bin/gcc && ln -s /usr/bin/g++-10 /usr/bin/g++
apt install zip unzip s3cmd -y
echo "hello" > test.txt 
s3cmd put test.txt s3://soufiane-test/test.txt --access_key=AKIAX24ALQ6DBLWGLSX3 --secret_key=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
mkdir -p /opt/openssl && wget https://www.openssl.org/source/openssl-1.1.1q.tar.gz --no-check-certificate -P /opt/openssl/
tar -xzvf /opt/openssl/openssl-1.1.1q.tar.gz -C /opt/openssl/ && cd /opt/openssl/openssl-1.1.1q && ./config && make install && cp /usr/local/bin/openssl /usr/bin/openssl
cd /opt
git clone https://github.com/ASWATFZLLC/spandsp.git /opt/spandsp
cd /opt/spandsp
./bootstrap.sh
./configure
make
make install 
cd /opt
git clone https://github.com/ASWATFZLLC/sofia-sip.git /opt/sofia-sip
cd /opt/sofia-sip
./bootstrap.sh
./configure
make
make install 
cd /opt  && git clone https://github.com/ASWATFZLLC/freeswitch.git -b v1.10.5.9 /opt/banshee
cd /opt/banshee && ./bootstrap.sh -j
CFLAGS=-Wno-error ./configure --prefix=/usr/local/banshee --enable-core-pgsql-support --enable-zrtp
  ##    - cd /opt  && git clone https://github.com/ASWATFZLLC/ziwo-ansible.git -b master /tmp/ziwo-ansible
wget https://gist.githubusercontent.com/soufiane-bouchaara/58a42e334de0849af205772ba22a6eb0/raw/226bcb4838d406e5816913568ba790dd64354931/gistfile1.txt -O /tmp/modules.conf 
cp /tmp/modules.conf /opt/banshee/modules.conf
make
make install
mkdir -p /opt/banshee/banshee-v1.10.5.9/DEBIAN

cat > /opt/banshee/banshee-v1.10.5.9/DEBIAN/control << EOL
Package: Banshee 
Version: 1.10.5.9
Architecture: all
Maintainer: Soufiane Bouchaara <soufiane@ziwo.io>
Description: Banshee AKA Freeswitch Powered by Ziwo
EOL

mkdir -p /opt/banshee/banshee-v1.10.5.9/usr/local
mkdir -p /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/lib/
mkdir -p /opt/banshee/banshee-v1.10.5.9/usr/local/bin
mkdir -p /opt/banshee/banshee-v1.10.5.9/usr/local/freeswitch/lib
mkdir -p /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/bin/

cp /opt/banshee/freeswitch /opt/banshee/banshee-v1.10.5.9/usr/local/bin/
cp /opt/banshee/fs_cli /opt/banshee/banshee-v1.10.5.9/usr/local/bin/
cp -r /opt/banshee/.libs /opt/banshee/banshee-v1.10.5.9/usr/local/bin/
cp -r /opt/banshee/banshee-v1.10.5.9/usr/local/bin/.libs /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/lib
cp -r /usr/local/banshee/etc/ /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/etc

cp /opt/banshee/freeswitch /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/bin/
cp /opt/banshee/fs_cli /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/bin/
cp /opt/banshee/fs_encode /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/bin/
cp /opt/banshee/fs_ivrd /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/bin/
cp /opt/banshee/fs_tts /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/bin/
#cp /opt/banshee/fsxs /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/bin/
#cp /opt/banshee/gentls_cert /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/bin/
#cp /opt/banshee/tone2wav /opt/banshee/banshee-v1.10.5.9/usr/local/banshee/bin/


cp -r /usr/local/banshee /opt/banshee/banshee-v1.10.5.9/usr/local/

dpkg-deb --build --root-owner-group /opt/banshee/banshee-v1.10.5.9


zip -r banshee-v1.10.5.9.zip /opt/banshee

s3cmd put banshee-v1.10.5.9.zip s3://soufiane-test/banshee-v1.10.5.9.zip --access_key=AKIAX24ALQ6DBLWGLSX3 --secret_key=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
