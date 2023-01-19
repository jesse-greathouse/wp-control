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

sudo yum-config-manager --enable epel

# install dependencies
sudo yum -y update && sudo yum -y install \
  gcc gcc-c++ intltool autoconf autoconf python3.8 python3-pip gcc perl pcre expect \
  git-core curl libcurl-devel pkgconfig openssl openssl-devel mariadb-client mariadb-devel libxslt-devel \
  pcre2 libxml2 libxml2-devel libicu-devel ImageMagick-devel ImageMagick libzip ncurses-devel oniguruma-devel glib2-devel libzip-devel

# install Sodium
curl -o ${OPT}/libsodium-1.0.18-1.el7.x86_64.rpm https://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/l/libsodium-1.0.18-1.el7.x86_64.rpm
sudo rpm -ivh ${OPT}/libsodium-1.0.18-1.el7.x86_64.rpm
rm ${OPT}/libsodium-1.0.18-1.el7.x86_64.rpm

# install Sodium-devel
curl -o ${OPT}/libsodium-devel-1.0.18-1.el7.x86_64.rpm https://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/l/libsodium-devel-1.0.18-1.el7.x86_64.rpm
sudo rpm -ivh ${OPT}/libsodium-devel-1.0.18-1.el7.x86_64.rpm
rm ${OPT}/libsodium-devel-1.0.18-1.el7.x86_64.rpm

sudo amazon-linux-extras enable python3.8
pip3 install supervisor

export PATH=$PATH:/usr/local/mysql/bin

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
${OPT}/pear/bin/pecl install imagick

cd ${DIR}

# Download and Install Wordpress
curl -o ${OPT}/wordpress.tar.gz https://wordpress.org/latest.tar.gz
tar -xf ${OPT}/wordpress.tar.gz -C ${OPT}/ --exclude="wp-content"
cp -r ${OPT}/wordpress/* ${WEB}/

# Download Wordpress CLI
if [ -f "${BIN}/wp-cli.phar" ]; then
  rm ${BIN}/wp-cli.phar
fi
curl -o ${BIN}/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x ${BIN}/wp-cli.phar

# Cleanup
rm -rf ${OPT}/php-*/
rm ${OPT}/wordpress.tar.gz
rm -rf ${OPT}/wordpress
rm -rf ${OPT}/openresty-*/

# Run the configuration
${BIN}/configure-amazon.sh