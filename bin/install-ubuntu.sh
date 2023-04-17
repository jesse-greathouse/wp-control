#!/usr/bin/env bash

#   +---------------------------------------------------------------------------------+
#   | This file is part of wp-control                                       |
#   +---------------------------------------------------------------------------------+
#   | Copyright (c) 2023 Greathouse Technology LLC (http://www.greathouse.technology) |
#   +---------------------------------------------------------------------------------+
#   | wp-control is free software: you can redistribute it and/or modify    |
#   | it under the terms of the GNU General Public License as published by            |
#   | the Free Software Foundation, either version 3 of the License, or               |
#   | (at your option) any later version.                                             |
#   |                                                                                 |
#   | wp-control is distributed in the hope that it will be useful,         |
#   | but WITHOUT ANY WARRANTY; without even the implied warranty of                  |
#   | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                   |
#   | GNU General Public License for more details.                                    |
#   |                                                                                 |
#   | You should have received a copy of the GNU General Public License               |
#   | along with wp-control.  If not, see <http://www.gnu.org/licenses/>.   |
#   +---------------------------------------------------------------------------------+
#   | Author: Jesse Greathouse <jesse@greathouse.technology>                          |
#   +---------------------------------------------------------------------------------+

# resolve real path to script including symlinks or other hijinks
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  TARGET="$(readlink "$SOURCE")"
  if [[ ${TARGET} == /* ]]; then
    echo "SOURCE '$SOURCE' is an absolute symlink to '$TARGET'"
    SOURCE="$TARGET"
  else
    BIN="$( dirname "$SOURCE" )"
    echo "SOURCE '$SOURCE' is a relative symlink to '$TARGET' (relative to '$BIN')"
    SOURCE="$BIN/$TARGET" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  fi
done
USER="$( whoami )"
RBIN="$( dirname "$SOURCE" )"
BIN="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
DIR="$( cd -P "$BIN/../" && pwd )"
ETC="$( cd -P "$DIR/etc" && pwd )"
OPT="$( cd -P "$DIR/opt" && pwd )"
SRC="$( cd -P "$DIR/src" && pwd )"
WEB="$( cd -P "$DIR/web" && pwd )"

#install dependencies
sudo apt-get update && sudo apt-get install -y \
  supervisor authbind openssl build-essential intltool autoconf automake gcc perl curl pkg-config expect cpanminus \
  mysql-client imagemagick libpcre++-dev libcurl4 libcurl4-openssl-dev libmagickwand-dev libssl-dev libxslt1-dev \
  libmysqlclient-dev libpcre2-dev libxml2 libxml2-dev libicu-dev libmagick++-dev libzip-dev libonig-dev libsodium-dev libglib2.0-dev

# Compile and Install Openresty
tar -xzf ${OPT}/openresty-*.tar.gz -C ${OPT}/

# Fix the escape frontslash feature of cjson
sed -i -e s/"    NULL, NULL, NULL, NULL, NULL, NULL, NULL, \"\\\\\\\\\/\","/"    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,"/g ${OPT}/openresty-*/bundle/lua-cjson-2.1.0.7/lua_cjson.c

cd ${OPT}/openresty-*/
./configure --prefix=${OPT}/openresty \
            --with-pcre-jit \
            --with-ipv6 \
            --with-http_iconv_module \
            --with-http_realip_module \
            --with-http_ssl_module \
            -j2 && \
make
make install

cd ${DIR}

# Compile and Install PHP
tar -xf ${OPT}/php-*.tar.gz -C ${OPT}/
cd ${OPT}/php-*/

./configure \
  --prefix=${OPT}/php \
  --sysconfdir=${ETC} \
  --with-config-file-path=${ETC}/php \
  --with-config-file-scan-dir=${ETC}/php/conf.d \
  --enable-opcache \
  --enable-fpm \
  --enable-dom \
  --enable-exif \
  --enable-fileinfo \
  --enable-json \
  --enable-mbstring \
  --enable-bcmath \
  --enable-intl \
  --enable-ftp \
  --without-sqlite3 \
  --without-pdo-sqlite \
  --with-libxml \
  --with-xsl \
  --with-xmlrpc \
  --with-zlib \
  --with-curl \
  --with-webp \
  --with-openssl \
  --with-zip \
  --with-sodium \
  --with-mysqli \
  --with-pdo-mysql \
  --with-mysql-sock \
  --with-iconv
make
make install

# Install perl modules
sudo cpanm JSON
sudo cpanm YAML::XS
sudo cpanm LWP::UserAgent
sudo cpanm LWP::Protocol::https
sudo cpanm Term::Menus
sudo cpanm Archive::Zip
sudo cpanm File::Slurper
sudo cpanm File::HomeDir
sudo cpanm File::Find::Rule

# Install Pear and ImageMagick extension
# If php.ini exists, hide it before pear installs
if [ -f "${ETC}/php/php.ini" ]; then
  mv ${ETC}/php/php.ini ${ETC}/php/hidden.ini
fi

# Use expect to install Pear non-interactively
${BIN}/install-pear.sh ${OPT}

#replace the php.ini file
if [ -f "${ETC}/hidden.ini" ]; then
  mv ${ETC}/php/hidden.ini ${ETC}/php/php.ini
fi

# Build imagick extension with pecl
export PATH="${OPT}/php/bin:${PATH}"
${OPT}/pear/bin/pecl install imagick --D PREFIX=""

cd ${BIN}

# Download and Install Wordpress
OPT=${OPT} WEB=${WEB} ${BIN}/install-wordpress.pl

# Install the Wordpress Skeleton
DIR=${DIR} ${BIN}/install-wp-skeleton.pl

cd ${DIR}

# Download Wordpress CLI
if [ -f "${BIN}/wp-cli.phar" ]; then
  rm ${BIN}/wp-cli.phar
fi
curl -o ${BIN}/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x ${BIN}/wp-cli.phar

# Cleanup
rm -rf ${OPT}/php-*/
rm ${OPT}/wordpress-*.zip
rm -rf ${OPT}/openresty-*/

# Run the configuration
${BIN}/configure-ubuntu.sh
