<?php

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

if (!defined('PORT')) {
    define('PORT', $_ENV['PORT']);
}

if (!defined('DEBUG')) {
    define('DEBUG', settype($_ENV['DEBUG'], "boolean"));
}

// Disable display of errors and warnings
// It is recommended to never display PHP errors on the page
// Use var/log/error.log to see errors.
if (!defined('WP_DEBUG_DISPLAY')) {
    define( 'WP_DEBUG_DISPLAY', false );
}

if (!defined('WP_REDIS_CLIENT')) {
    define('WP_REDIS_CLIENT', 'phpredis');
}

if (!defined('REDIS_HOST')) {
    define('REDIS_HOST', $_ENV['REDIS_HOST']);
}

if (!defined('REDIS_PORT')) {
    define('REDIS_PORT', $_ENV['REDIS_PORT']);
}

if (!defined('REDIS_DB')) {
    define('REDIS_DB', $_ENV['REDIS_DB']);
}

if (!defined('REDIS_PASSWORD')) {
    define('REDIS_PASSWORD', $_ENV['REDIS_PASSWORD']);
}

// Decide between socket vs TCP
if (!defined('WP_REDIS_PATH') && strlen(REDIS_HOST) > 0 && REDIS_HOST[0] === '/') {
    // REDIS_HOST is a Unix socket path
    define('WP_REDIS_PATH', REDIS_HOST);
} else if (!defined('WP_REDIS_HOST')) {
    // Otherwise assume it's a hostname or IP
    define('WP_REDIS_HOST', REDIS_HOST);
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

define('DB_CHARSET', 'utf8');

define('DB_COLLATE', '');

// Optional user-defined local environment overrides
$envLocalPath = WEB_DIR . DIRECTORY_SEPARATOR . 'env-local.php';

if (file_exists($envLocalPath)) {
    require $envLocalPath;
}
