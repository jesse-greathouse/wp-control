#!/usr/bin/perl

package WPControl::Configure;
use strict;
use File::Basename;
use Cwd qw(getcwd abs_path);
use Exporter 'import';
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use Term::Prompt;
use Term::Prompt qw(termwrap);
use Term::ANSIScreen qw(cls);
use lib(dirname(abs_path(__FILE__))  . "/../modules");
use WPControl::Config qw(get_configuration save_configuration);
use WPControl::Utility qw(splash);

our @EXPORT_OK = qw(configure);

my $os = get_operating_system();
my $osModule = 'WPControl::Configure::' . $os;
eval "use $osModule qw(
    get_user_input
)";
warn $@ if $@; # handle exception

my $user = $ENV{'LOGNAME'} || $ENV{'USER'} || getpwuid($<);
my $bin = abs_path(dirname(__FILE__) . '/../../');
my $applicationRoot = abs_path(dirname($bin));
my $etc = $applicationRoot . '/etc';
my $opt = $applicationRoot . '/opt';
my $src = $applicationRoot . '/src';
my $web = $applicationRoot . '/web';
my $passwordMatchAttempts = 0;
my $adminPasswordConfirm = '';
my %cfg = get_configuration();

1;

# ====================================
#    Subroutines below this point
# ====================================

# Trim the whitespace from a string.
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

# Returns string associated with operating system.
sub get_operating_system {
    return 'Ubuntu';
}

# Performs the install routine.
sub configure {
    cls();
    splash();

    print (''."\n");
    print ('================================================================='."\n");
    print (' This will create your site\'s run script'."\n");
    print ('================================================================='."\n");
    print (''."\n");

    request_user_input();

    save_configuration(%cfg);
}

# Runs the user through a series of setup config questions.
# Confirms the answers.
# Returns Hash Table
sub request_user_input {
    # Save the input variables to the configuration.
    $cfg{'meta'}{'site_name'} = '';
    $cfg{'redis'}{'redis_host'} = '';
    $cfg{'nginx'}{'port'} = '';
    $cfg{'nginx'}{'ssl_pair'} = '';
    $cfg{'nginx'}{'ssl_cert'} = '';
    $cfg{'nginx'}{'ssl_key'} = '';
    $cfg{'nginx'}{'main_domain'} = '';
    $cfg{'nginx'}{'site_domains'} = '';
    $cfg{'wordpress'}{'admin_email'} = '';
    $cfg{'wordpress'}{'admin_password'} = '';
    $cfg{'wordpress'}{'site_title'} = '';
    $cfg{'wordpress'}{'db_host'} = '';
    $cfg{'wordpress'}{'db_name'} = '';
    $cfg{'wordpress'}{'db_user'} = '';
    $cfg{'wordpress'}{'db_password'} = '';
    $cfg{'wordpress'}{'db_port'} = '';
    $cfg{'wordpress'}{'replace_keys_and_salts'} = '';
    $cfg{'wordpress'}{'debug'} = '';

    # SITE_NAME
    if ($cfg{'meta'}{'site_name'} eq '') {
        input_site_name();
    }

    # ADMIN_EMAIL
    if ($cfg{'wordpress'}{'admin_email'} eq '') {
        input_admin_email();
    }

    # ADMIN_PASSWORD
    if ($cfg{'wordpress'}{'admin_password'} eq '') {
        input_admin_password();
    }

    if ($cfg{'wordpress'}{'site_title'} eq '') {
        input_site_title();
    }
}

sub input_site_name {
    $cfg{'meta'}{'site_name'} = prompt('x', 'Profile name of this site:', '', '');
}

sub input_admin_email {
    $cfg{'wordpress'}{'admin_email'} = prompt('x', 'Admin email address of your site:', '', '');
}

sub input_site_title {
    $cfg{'wordpress'}{'site_title'} = prompt('x', 'WordPress Title of your site:', '', 'Just Another WordPress Site');
}

sub input_admin_password {
    if ($cfg{'wordpress'}{'admin_password'} eq '' or ($adminPasswordConfirm ne $cfg{'wordpress'}{'admin_password'})) {
        ++$passwordMatchAttempts;

        if ($passwordMatchAttempts > 3) {
            die ("Too many failed Admin Password Confirmations. Please run the script again to configure.\n");
        }

        if ($passwordMatchAttempts > 1) {
            print termwrap("The Admin Password did not match with the confirmation.\nPlease attempt to provide the Admin Password Again.\n");
        }

        $cfg{'wordpress'}{'admin_password'} = prompt('p', 'Admin password of your site:', '', '');
        print "\n";
        $adminPasswordConfirm = prompt('p', 'Confirm the Admin password of your site:', '', '');
        print "\n";

        input_admin_password();
    }
}
