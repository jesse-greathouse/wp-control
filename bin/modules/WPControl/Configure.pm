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
use WPControl::Utility qw(splash generate_rand_str);
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

# Default Supervisor control ports
my $supervisorPort = 5962;

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
    MAIN_DOMAIN  => 'example.com',
    SITE_DOMAINS => 'www.example.com',
  },
  wordpress => {
      SITE_TITLE     => 'Just Another WordPress Site',
      DB_HOST        => '127.0.0.1',
      DB_PORT        => '3306',
      DEBUG          => 'true',
  },
  supervisors => {
      SUPERVISORCTL_USER => $ENV{"LOGNAME"},
  },
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
        print " This will configure your WordPress hosting environment\n";
        print "=================================================================\n\n";
        merge_defaults();
        prompt_user_input();
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
        prompt_refresh_keys_and_salts();
        prompt_admin_password();
    } else {
        # run keys and salts if it doesn't exist:
        -e $keysAndSalts or refresh_keys_and_salts();

        print "\nConfiguration completed in non-interactive mode.\n";
        print "Note: If this is a fresh install, be sure to manually run the following commands as needed:\n";
        print "  bin/refresh-wp-keys-and-salts  # Run database migrations\n";
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

sub assign_dynamic_config {
    # Assign essential directory paths
    $cfg{nginx}{WEB}          //= $webDir;
    $cfg{nginx}{VAR}          //= $varDir;
    $cfg{nginx}{LOG}          //= $logDir;
    $cfg{nginx}{ETC}          //= $etcDir;
    $cfg{nginx}{OPT}          //= $optDir;
    $cfg{nginx}{SRC}          //= $srcDir;
    $cfg{nginx}{TMP}          //= $tmpDir;
    $cfg{nginx}{BIN}          //= $binDir;
    $cfg{nginx}{CACHE}        //= $cacheDir;
    $cfg{nginx}{DIR}          //= $applicationRoot;

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
    $cfg{supervisord}{SUPERVISORCTL_PORT} //= $supervisorPort;
}

sub prompt_user_input {
      my @fields = (
        ['meta',      'SITE_NAME',     'Site Label'],
        ['wordpress', 'ADMIN_EMAIL',   'Admin Email Address'],
        ['wordpress', 'SITE_TITLE',    'Site Title'],
        ['wordpress', 'DB_HOST',       'Database Host'],
        ['wordpress', 'DB_NAME',       'Database Name'],
        ['wordpress', 'DB_USER',       'Database Username'],
        ['wordpress', 'DB_PASSWORD',   'Database Password'],
        ['wordpress', 'DB_PORT',       'Database Port'],
        ['wordpress', 'DEBUG',         'Enable Debugging'],
        ['nginx',     'MAIN_DOMAIN',   'Primary Domain Name'],
        ['nginx',     'SITE_DOMAINS',  'Additional Domains (space-separated)'],
        ['nginx',     'IS_SSL',        'Enable SSL (HTTPS)'],
        ['nginx',     'SSL_CERT',      'SSL Certificate Path (if using HTTPS)'],
        ['nginx',     'SSL_KEY',       'SSL Key Path (if using HTTPS)'],
        ['nginx',     'PORT',          'Web Server Port'],
    );

    foreach my $field (@fields) {
        my ($domain, $key, $label) = @$field;
        if ($key =~ /DEBUG|IS_SSL/) {
            $cfg{$domain}{$key} = prompt_boolean($cfg{$domain}{$key}, $label);
        } elsif ($key =~ /PORT/) {
            $cfg{$domain}{$key} = prompt_integer($cfg{$domain}{$key}, $label);
        } else {
            $cfg{$domain}{$key} = prompt('x', "$label:", '', $cfg{$domain}{$key});
        }
    }
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
      #TODO: Change admin passowrd.
    }
}

1;
