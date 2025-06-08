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

FROM alpine:3.11
LABEL maintainer="Jesse Greathouse <jesse.greathouse@gmail.com>"

ENV PATH /app/bin:/app/opt/php/bin:$PATH

# Get core utils
RUN apk add --no-cache \
    bash curl openssh g++ gcc make nasm git file coreutils python perl autoconf pkgconf supervisor expect ca-certificates \
    readline-dev libxslt-dev ncurses-dev curl-dev libc-dev dpkg-dev pcre-dev mariadb-dev mariadb-connector-c libressl-dev \
    libxml2-dev icu-dev libzip-dev oniguruma-dev libsodium-dev glib-dev libsodium-dev imagemagick-dev

# Add preliminary file structure
RUN mkdir /app
RUN mkdir /app/bin
RUN mkdir /app/etc
RUN mkdir /app/etc/nginx
RUN mkdir /app/etc/php
RUN mkdir /app/etc/php-fpm.d
RUN mkdir /app/etc/ssl
RUN mkdir /app/etc/ssl/CA
RUN mkdir /app/etc/ssl/certs
RUN mkdir /app/etc/ssl/private
RUN mkdir /app/etc/supervisor
RUN mkdir /app/etc/supervisor/conf.d
RUN mkdir /app/opt
RUN mkdir /app/src
RUN mkdir /app/tmp
RUN mkdir /app/var
RUN mkdir /app/var/cache
RUN mkdir /app/var/cache/opcache
RUN mkdir /app/var/cache/wp-cli
RUN mkdir /app/var/keys
RUN mkdir /app/var/logs
RUN mkdir /app/var/pools
RUN mkdir /app/var/run
RUN mkdir /app/var/session
RUN mkdir /app/var/socket
RUN mkdir /app/var/upload
RUN mkdir /app/var/wp-cli
RUN mkdir /app/var/wp-cli/packages
RUN mkdir /app/web
RUN touch /app/error.log
ADD opt /app/opt

# Add Scripts
ADD bin/install.sh /app/bin/install.sh
ADD bin/install-pear.sh /app/bin/install-pear.sh
ADD bin/generate-diffie-hellman.pl /app/bin/generate-diffie-hellman.pl
ADD bin/cleancache /app/bin/cleancache

WORKDIR /app

# Run the install script
RUN bin/install.sh

# Remove all dependency tarballs
RUN rm -rf /app/opt/*tar.gz

# Project files
# etc
ADD etc/nginx/error_page.conf /app/etc/nginx/error_page.conf
ADD etc/nginx/fastcgi_params.conf /app/etc/nginx/fastcgi_params.conf
ADD etc/nginx/lua_env.conf /app/etc/nginx/lua_env.conf
ADD etc/nginx/lua_package_cpath.conf /app/etc/nginx/lua_package_cpath.conf
ADD etc/nginx/lua_package_path.conf /app/etc/nginx/lua_package_path.conf
ADD etc/nginx/mime_types.conf /app/etc/nginx/mime_types.conf
ADD etc/nginx/proxy.conf /app/etc/nginx/proxy.conf
ADD etc/php/browscap.ini /app/etc/php/browscap.ini
ADD etc/supervisor/conf.d/supervisord.docker.conf /app/etc/supervisor/conf.d/supervisord.conf
# src
ADD src/ /app/src
# web
ADD web/ /app/web

# Expose ports
EXPOSE 3000

CMD ["/usr/bin/supervisord", "-c", "/app/etc/supervisor/conf.d/supervisord.conf"]
