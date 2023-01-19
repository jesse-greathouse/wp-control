<?php

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

if (!defined('USER')) {
    define('USER', $_ENV['USER']);
}

if (!defined('BASE_DIR')) {
    define('BASE_DIR', $_ENV['DIR']);
}

if (!defined('BIN_DIR')) {
    define('BIN_DIR', $_ENV['BIN']);
}

if (!defined('ETC_DIR')) {
    define('ETC_DIR', $_ENV['ETC']);
}

if (!defined('OPT_DIR')) {
    define('OPT_DIR', $_ENV['OPT']);
}

if (!defined('SRC_DIR')) {
    define('SRC_DIR', $_ENV['SRC']);
}

if (!defined('TMP_DIR')) {
    define('TMP_DIR', $_ENV['TMP']);
}

if (!defined('VAR_DIR')) {
    define('VAR_DIR', $_ENV['VAR']);
}

if (!defined('WEB_DIR')) {
    define('WEB_DIR', $_ENV['WEB']);
}

if (!defined('CACHE_DIR')) {
    define('CACHE_DIR', $_ENV['CACHE_DIR']);
}

if (!defined('LOG_DIR')) {
    define('LOG_DIR', $_ENV['LOG_DIR']);
}

if (!defined('DEBUG')) {
    define('DEBUG', settype($_ENV['DEBUG'], "boolean"));
}

if (!defined('REDIS_HOST')) {
    define('REDIS_HOST', $_ENV['REDIS_HOST']);
}

if (!defined('DB_NAME')) {
    define('DB_NAME', $_ENV['DB_NAME']);
}

if (!defined('DB_USER')) {
    define('DB_USER', $_ENV['DB_USER']);
}

if (!defined('DB_PASSWORD')) {
    define('DB_PASSWORD', $_ENV['DB_PASSWORD']);
}

if (!defined('DB_HOST')) {
    define('DB_HOST', $_ENV['DB_HOST']);
}

if (!defined('DB_PORT')) {
    define('DB_PORT', $_ENV['DB_PORT']);
}

if (!defined('DS')) {
    define('DS', DIRECTORY_SEPARATOR);
}
