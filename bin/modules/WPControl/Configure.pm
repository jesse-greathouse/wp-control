#!/usr/bin/perl

package WPControl::Configure;

use strict;
use warnings;
use Exporter 'import';
use File::Basename;
use Cwd qw(abs_path);
use Term::Prompt qw(prompt termwrap);
use Term::ANSIScreen qw(cls);
use lib(dirname(abs_path(__FILE__)) . "/../modules");
use WPControl::Config qw(get_configuration save_configuration write_config_file);
use WPControl::Utility qw(
    splash generate_rand_str validate_required_fields
);
use WPControl::RefreshKeysAndSalts qw(refresh_keys_and_salts);

our @EXPORT_OK = qw(configure configure_help);

warn $@ if $@;

# ------------------------
# Define Application Paths
# ------------------------

my $binDir          = abs_path(dirname(__FILE__) . '/../../');
my $applicationRoot = abs_path(dirname($binDir));
my $etcDir          = "$applicationRoot/etc";
my $optDir          = "$applicationRoot/opt";
my $varDir          = "$applicationRoot/var";
my $webDir          = "$applicationRoot/web";
my $srcDir          = "$applicationRoot/src";
my $tmpDir          = "$applicationRoot/tmp";
my $logDir          = "$varDir/log";
my $cacheDir        = "$varDir/cache";

my $secret = generate_rand_str();

# Files
my $sslCertificate  = "$etcDir/ssl/certs/wp-control.cert";
my $sslKey          = "$etcDir/ssl/private/wp-control.key";
my $errorLog        = "$logDir/error.log";
my $keysAndSalts    = "$varDir/keys/wordpress-keys-and-salts.php";

# ------------------------
# Load and Define Config
# ------------------------

my %cfg = get_configuration();

# List of configuration files to be written
my %config_files = (
    php_ini             => ["$etcDir/php/php.dist.ini",                         "$etcDir/php/php.ini"],
    php_fpm             => ["$etcDir/php-fpm.d/php-fpm.dist.conf",              "$etcDir/php-fpm.d/php-fpm.conf"],
    force_ssl           => ["$etcDir/nginx/force-ssl.dist.conf",                "$etcDir/nginx/force-ssl.conf"],
    ssl_params          => ["$etcDir/nginx/ssl-params.dist.conf",               "$etcDir/nginx/ssl-params.conf"],
    nginx               => ["$etcDir/nginx/nginx.dist.conf",                    "$etcDir/nginx/nginx.conf"],
    wordpress_cfg       => ["$etcDir/wordpress/wp-config.php",                  "$webDir/wp-config.php"],
    wordpress_env       => ["$etcDir/wordpress/env.php",                        "$webDir/env.php"],
    supervisord         => ["$etcDir/supervisor/conf.d/supervisord.conf.dist",  "$etcDir/supervisor/conf.d/supervisord.conf"],
);

# Default values
my %defaults = (
  nginx => {
    PORT         => '8181',
    SSL_CERT     => $sslCertificate,
    SSL_KEY      => $sslKey,
    IS_SSL       => 'false',
    HOST_NAMES   => '127.0.0.1 localhost',
  },
  wordpress => {
      SITE_TITLE     => 'Just Another WordPress Site',
      SITE_URL       => 'http://localhost:8181',
      DB_HOST        => '127.0.0.1',
      DB_PORT        => '3306',
      DEBUG          => 'true',
      REDIS_DB       => '0',
      REDIS_HOST     => '127.0.0.1',
      REDIS_PASSWORD => 'null',
      REDIS_PORT     => '6379',
  },
  supervisord => {
      SUPERVISORCTL_USER => $ENV{"LOGNAME"},
  },
);

my @required_fields = (
    ['meta',      'SITE_NAME'],
    ['wordpress', 'ADMIN_EMAIL'],
    ['wordpress', 'DB_NAME'],
    ['wordpress', 'DB_USER'],
    ['wordpress', 'DB_PASSWORD'],
);

# ================================
#       PUBLIC ENTRYPOINTS
# ================================

sub configure_help {
    print <<'EOF';
Usage: configure [--option]

Sets up the wp-control configuration system. By default, the script runs in interactive mode.

Examples:
  configure                   # Run interactive configuration
  configure --non-interactive # Use default or pre-defined values

Available options:
  --non-interactive   Skip all interactive prompts
  help                Show this help message
EOF
}

sub configure {
    my ($interactive) = @_;
    $interactive = 1 unless defined $interactive;

    if ($interactive) {
        cls();
        splash();
        print "\n=================================================================\n";
        print " This will configure your WordPress Application Environment\n";
        print "=================================================================\n\n";
        merge_defaults();
        prompt_user_input();

        # Stop here if required fields were not submitted.
        validate_required_fields(\@required_fields, \%cfg);
    }

    assign_dynamic_config();
    save_configuration(%cfg);

    # Refreshes the cfg variable with exactly what was just written to the file.
    my %liveCfg = get_configuration();

    # Write configuration files
    foreach my $key (keys %config_files) {
      write_config(@{$config_files{$key}}, \%liveCfg);
    }

    if ($interactive) {
        prompt_wp_install();
        prompt_wp_skeleton_install();
        prompt_db_install();
        do_db_backup();
        prompt_refresh_keys_and_salts();
        prompt_admin_password();
    } else {
        # run keys and salts if it doesn't exist:
        -e $keysAndSalts or refresh_keys_and_salts();

        print "\nConfiguration completed in non-interactive mode.\n";
        print "Note: If this is a fresh install, be sure to manually run the following commands as needed:\n\n";
        print "  bin/install-wordpress           # Install or update WordPress core files\n";
        print "  bin/install-wp-skeleton         # Install or update site code, plugins, and themes\n";
        print "  bin/install-wp-db               # Install the WordPress database tables\n";
        print "  bin/db-backup                   # Install the WordPress database tables\n";
        print "  bin/refresh-wp-keys-and-salts   # Refresh security keys and invalidate existing sessions\n\n";
    }
}

# ================================
#        SUBROUTINES
# ================================

# Writes a configuration file from its template.
sub write_config {
    my ($distFile, $outFile, $config_ref) = @_;
    return unless -e $distFile;
    write_config_file($distFile, $outFile, %$config_ref);
}

sub merge_defaults {
    foreach my $domain (keys %defaults) {
        foreach my $key (keys %{$defaults{$domain}}) {
            $cfg{$domain}{$key} //= $defaults{$domain}{$key};
        }
    }
}

sub is_required {
    my ($d, $k) = @_;
    return grep { $_->[0] eq $d && $_->[1] eq $k } @required_fields;
}

sub assign_dynamic_config {
    # Assign essential directory paths
    $cfg{nginx}{DIR}          //= $applicationRoot;
    $cfg{nginx}{WEB}          //= $webDir;
    $cfg{nginx}{VAR}          //= $varDir;
    $cfg{nginx}{ETC}          //= $etcDir;
    $cfg{nginx}{OPT}          //= $optDir;
    $cfg{nginx}{SRC}          //= $srcDir;
    $cfg{nginx}{TMP}          //= $tmpDir;
    $cfg{nginx}{BIN}          //= $binDir;
    $cfg{nginx}{CACHE_DIR}    //= $cacheDir;
    $cfg{nginx}{LOG_DIR}      //= $cacheDir;
    $cfg{nginx}{LOG}          //= $errorLog;

    $cfg{nginx}{REDIS_HOST}     //= $cfg{wordpress}{REDIS_HOST};
    $cfg{nginx}{REDIS_DB}       //= $cfg{wordpress}{REDIS_DB};
    $cfg{nginx}{REDIS_PORT}     //= $cfg{wordpress}{REDIS_PORT};
    $cfg{nginx}{REDIS_PASSWORD} //= $cfg{wordpress}{REDIS_PASSWORD};

    $cfg{nginx}{USER} //= $ENV{"LOGNAME"};
    $cfg{nginx}{SESSION_SECRET} //= $secret;

    if ($cfg{nginx}{IS_SSL} eq 'true') {
        $cfg{nginx}{SSL_CERT_LINE} = "ssl_certificate $cfg{nginx}{SSL_CERT};";
        $cfg{nginx}{SSL_KEY_LINE}  = "ssl_certificate_key $cfg{nginx}{SSL_KEY};";
        $cfg{nginx}{INCLUDE_FORCE_SSL} = "include $etcDir/nginx/force-ssl.conf;";
        $cfg{nginx}{SSL} = "ssl";
    } else {
        $cfg{nginx}{SSL_CERT_LINE} = "";
        $cfg{nginx}{SSL_KEY_LINE}  = "";
        $cfg{nginx}{INCLUDE_FORCE_SSL} = "";
        $cfg{nginx}{SSL} = "";
    }

    # Assign dynamically generated values that are not part of %defaults
    $cfg{supervisord}{SUPERVISORCTL_USER} //= $ENV{"LOGNAME"};
    $cfg{supervisord}{SUPERVISORCTL_SECRET} //= $secret;
}

sub prompt_user_input {
    my $default;
    my @fields = (
        ['meta',        'SITE_NAME',          'Site Label'],
        ['nginx',       'HOST_NAMES',         'Server Host Names (nginx server_name)'],
        ['nginx',       'IS_SSL',             'Enable SSL (HTTPS)'],
        ['nginx',       'SSL_CERT',           'SSL Certificate Path (if using HTTPS)'],
        ['nginx',       'SSL_KEY',            'SSL Key Path (if using HTTPS)'],
        ['nginx',       'PORT',               'Web Server Port'],
        ['supervisord', 'SUPERVISORCTL_PORT', 'Supervisor Control Port'],
        ['wordpress',   'ADMIN_EMAIL',        'Admin Email Address'],
        ['wordpress',   'SITE_TITLE',         'Site Title'],
        ['wordpress',   'SITE_URL',           'Site URL (WordPress siteurl)'],
        ['wordpress',   'DEBUG',              'Enable Debugging'],
        ['wordpress',   'DB_HOST',            'Database Host'],
        ['wordpress',   'DB_NAME',            'Database Name'],
        ['wordpress',   'DB_USER',            'Database Username'],
        ['wordpress',   'DB_PASSWORD',        'Database Password'],
        ['wordpress',   'DB_PORT',            'Database Port'],
        ['wordpress',   'REDIS_HOST',         'Redis Host'],
        ['wordpress',   'REDIS_PORT',         'Redis Port'],
        ['wordpress',   'REDIS_PASSWORD',     'Redis Password (or null)'],
        ['wordpress',   'REDIS_DB',           'Redis DB Index'],
    );

    foreach my $field (@fields) {
        my ($domain, $key, $label) = @$field;

        if ($domain eq 'supervisord' && $key eq 'SUPERVISORCTL_PORT') {
            $cfg{$domain}{$key} = prompt_supervisor_port();
        }
        elsif ($key =~ /DEBUG|IS_SSL/) {
            $cfg{$domain}{$key} = prompt_boolean($cfg{$domain}{$key}, $label);
        }
        elsif ($key =~ /PORT/) {
            $cfg{$domain}{$key} = prompt_integer($cfg{$domain}{$key}, $label);
        }
        elsif (is_required($domain, $key)) {
            $default = defined $cfg{$domain}{$key} ? ($cfg{$domain}{$key} || '') : '';
            $cfg{$domain}{$key} = prompt_with_validation($domain, $key, $label, $default);
        }
        else {
            $cfg{$domain}{$key} = prompt('x', "$label:", '', $cfg{$domain}{$key});
        }
    }
}

sub prompt_supervisor_port {
    my $current = $cfg{supervisord}{SUPERVISORCTL_PORT};
    my $default;

    if (defined($current) && $current =~ /^\d+$/) {
        $default = $current;
    } else {
        srand();
        $default = int(40000 + rand(20000));
    }

    return prompt_integer($default, 'Supervisor Control Port');
}

sub prompt_boolean {
    my ($default, $label) = @_;
    $default //= 'false';
    my $prompt_val = ($default eq 'true') ? 'y' : 'n';
    return prompt('y', "$label", '', $prompt_val) ? 'true' : 'false';
}

sub prompt_integer {
    my ($default, $label) = @_;
    while (1) {
        my $val = prompt('x', "$label (integer):", '', $default);
        return $val if $val =~ /^\d+$/;
        print "Invalid input. Please enter an integer.\n";
    }
}

sub prompt_with_validation {
    my ($domain, $key, $label, $default) = @_;
    my $help = '';
    $help = 'value required' if $default eq '';

    my $value = prompt(
        's',               # 's' = code ref validation
        "$label:",         # prompt message
        $help,             # help text
        $default,          # default
        sub { 1; }
    );

    return $value;
}

sub prompt_wp_install {
    require WPControl::Utility;
    WPControl::Utility->import(qw(get_wordpress_version));

    print "\n=================================================================\n";
    print " WordPress Codebase Check\n";
    print "=================================================================\n\n";

    my $version;
    eval {
        $version = get_wordpress_version();
    };

    if (!$@ && defined $version && $version ne '') {
        print "✅ WordPress is already installed.\n";
        print "→ Version: $version\n\n";
        return;
    }

    print "WordPress does not appear to be installed. Bootstrapping...\n\n";

    my $install_script = "$binDir/install-wordpress";

    unless (-x $install_script) {
        die "❌ Unable to locate or execute: $install_script\n";
    }

    system($install_script) == 0
        or die "❌ WordPress installation failed via: $install_script\n";
}


sub prompt_wp_skeleton_install {
    my $wp_content_dir = "$webDir/wp-content";

    # If the wp-content directory exists, WordPress skeleton is considered installed.
    return if -d $wp_content_dir;

    print "\n=================================================================\n";
    print " WordPress Skeleton Installation\n";
    print "=================================================================\n\n";

    print "WordPress skeleton not found. Bootstrapping...\n\n";

    my $skeleton_script = "$binDir/install-wp-skeleton";

    unless (-x $skeleton_script) {
        die "❌ Unable to locate or execute: $skeleton_script\n";
    }

    system($skeleton_script) == 0
        or die "❌ WordPress skeleton installation failed via: $skeleton_script\n";
}

sub prompt_db_install {
    require WPControl::Utility;
    WPControl::Utility->import(qw(
        is_wordpress_db_installed
        prompt_user_password
        install_wordpress_database
    ));

    # Skip if already installed
    if (is_wordpress_db_installed()) {
        return;
    }

    print "\n=================================================================\n";
    print " WordPress Database Installation\n";
    print "=================================================================\n\n";

    print "The WordPress database is not yet installed.\n";
    print "This will run 'wp core install' to bootstrap the database.\n\n";

    my $admin_user     = prompt('x', "Enter admin username:", '', 'admin');
    my $admin_password = prompt_user_password();

    my $url         = $cfg{wordpress}{SITE_URL};
    my $site_title  = $cfg{wordpress}{SITE_TITLE}  || 'Just Another WordPress Site';
    my $admin_email = $cfg{wordpress}{ADMIN_EMAIL} || '';

    unless ($admin_email) {
        die "❌ Admin email is not configured. Please set ADMIN_EMAIL in configuration.\n";
    }

    install_wordpress_database($url, $site_title, $admin_user, $admin_email, $admin_password);
}

# Displays a prompt to refresh WordPress Keys and Salts file.
sub prompt_refresh_keys_and_salts {

    if (!-e $keysAndSalts) {
        refresh_keys_and_salts();
        return;
    }

    print "\n=================================================================\n";
    print " Refresh WordPress Keys and Salts\n";
    print "=================================================================\n\n";

    print "Refresh WordPress Keys and Salts?\n";
    print "This will cancel all existing/active users sessions.\n\n";
    print "You can also run this manually later using: bin/refresh-wp-keys-and-salts\n\n";

    my $answer = prompt('y', "Refresh WordPress Keys and Salts?", '', "n");

    if ($answer eq 1) {
        refresh_keys_and_salts();
    } else {
        print "\n";
    }
}

# Optionally prompt to set the admin password post-configuration
sub prompt_admin_password {
    print "\n=================================================================\n";
    print " Admin User Password Change\n";
    print "=================================================================\n\n";

    print "Change the WordPress admin account password on demand.\n";
    print "You can provide it or skip this step.\n\n";

    my $answer = prompt('y', "Set the admin password now?", '', 'n');

    if ($answer eq 'y') {
      require WPControl::Utility;
      WPControl::Utility->import(qw(prompt_user_password update_wordpress_user_password));

      my $email = $cfg{wordpress}{ADMIN_EMAIL} // '';
      unless ($email) {
          print "❌ Admin email is not configured. Cannot proceed with password update.\n";
          return;
      }

      print "\nEnter a new password for the admin user ($email):\n";
      my $password = prompt_user_password();

      update_wordpress_user_password($email, $password);
  }
}

sub do_db_backup {
    require WPControl::Utility;
    WPControl::Utility->import(qw(is_wordpress_db_installed wordpress_database_backup));

    if (!is_wordpress_db_installed()) {
        return;
    }

    print "\n=================================================================\n";
    print " WordPress Database Backup\n";
    print "=================================================================\n\n";

    print "📀 Creating database snapshot...\n";
    wordpress_database_backup();
}

1;
