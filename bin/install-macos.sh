#!/usr/bin/env bash

#   +---------------------------------------------------------------------------------+
#   | This file is part of wp-control                                       |
#   +---------------------------------------------------------------------------------+
#   | Copyright (c) 2017 Greathouse Technology LLC (http://www.greathouse.technology) |
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
GROUP="$( users )"
RBIN="$( dirname "$SOURCE" )"
BIN="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
DIR="$( cd -P "$BIN/../" && pwd )"
ETC="$( cd -P "$DIR/etc" && pwd )"
OPT="$( cd -P "$DIR/opt" && pwd )"
SRC="$( cd -P "$DIR/src" && pwd )"
WEB="$( cd -P "$DIR/web" && pwd )"
TMP="$( cd -P "$DIR/tmp" && pwd )"

# verify apple command line tools are installed
XCODE="$( xcode-select -p )"

if [ "$XCODE" != "/Applications/Xcode.app/Contents/Developer" ]; then
	echo 'Please install Xcode command line tools and then run this script again.'
	echo 'You can install Xcode CLT with: xcode-select --install'
	exit 1
fi

#install dependencies
brew upgrade

brew install intltool autoconf automake gcc perl pcre \
  curl-openssl libiconv pkg-config openssl@1.1 mysql-client oniguruma \
  pcre2 libxml2 icu4c imagemagick mysql libsodium libzip glib

#install authbind -- allows a non root user to allow a program to bind to a port under 1025
cd ${OPT}
rm -rf ${OPT}/MacOSX-authbind/
git clone https://github.com/Castaglia/MacOSX-authbind.git
cd ${OPT}/MacOSX-authbind
make
sudo make install
cd ${DIR}

# If curl isn't available to the command line then add it to the PATH
if ! [ -x "$(command -v curl)" ]; then
  echo 'export PATH="/usr/local/opt/curl/bin:$PATH"' >> ~/.bash_profile
  export PATH="/usr/local/opt/curl/bin:${PATH}"
fi

# install supervisor with pip
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
chmod +x get-pip.py
python3 get-pip.py
rm get-pip.py
pip install supervisor

export PATH=$PATH:/usr/local/mysql/bin

# Compile and Install Openresty
tar -xf ${OPT}/openresty-*.tar.gz -C ${OPT}/

# Fix the escape frontslash feature of lua-cjson
sed -i '' s/"    NULL, NULL, NULL, NULL, NULL, NULL, NULL, \"\\\\\\\\\/\","/"    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,"/g ${OPT}/openresty-*/bundle/lua-cjson-2.1.0.7/lua_cjson.c

cd ${OPT}/openresty-*/

./configure --with-cc-opt="-I/usr/local/include -I/usr/local/opt/openssl/include" \
            --with-ld-opt="-L/usr/local/lib -L/usr/local/opt/openssl/lib" \
            --prefix=${OPT}/openresty \
            --with-pcre-jit \
            --with-ipv6 \
            --with-http_iconv_module \
            --with-http_realip_module \
            --with-http_ssl_module \
            -j2 && \
make install

cd ${DIR}

# Compile and Install PHP
tar -xf ${OPT}/php-*.tar.gz -C ${OPT}/
cd ${OPT}/php-*/

env PKG_CONFIG_PATH=/usr/local/opt/openssl/lib/pkgconfig:/usr/local/opt/libxml2/lib/pkgconfig:/usr/local/opt/icu4c/lib/pkgconfig:/usr/local/opt/pcre2/lib/pkgconfig \
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
    --with-zip=/usr/local/opt/libzip \
    --with-sodium=/usr/local/opt/sodium \
    --with-mysqli=/usr/local/bin/mysql_config \
    --with-pdo-mysql=mysqlnd \
    --with-mysql-sock=/tmp/mysql.sock \
    --with-iconv=/usr/local/opt/libiconv
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
printf "/usr/local/opt/imagemagick\n" | ${OPT}/pear/bin/pecl install imagick

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
rm -rf ${OPT}/MacOSX-*/

# Run the configuration
${BIN}/configure-macos.sh
