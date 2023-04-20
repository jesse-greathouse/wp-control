#!/usr/bin/perl

package WPControl::Install;
use strict;
use File::Basename;
use Cwd qw(getcwd abs_path);
use lib(dirname(abs_path(__FILE__))  . "/modules");
use Exporter 'import';
our @EXPORT_OK = qw(install);

my $user = $ENV{'LOGNAME'} || $ENV{'USER'} || getpwuid($<);
my $bin = abs_path(dirname(__FILE__) . '/../../');
my $applicationRoot = abs_path(dirname($bin));
my $etc = $applicationRoot . '/etc';
my $opt = $applicationRoot . '/opt';
my $src = $applicationRoot . '/src';
my $web = $applicationRoot . '/web';

my $os = get_operating_system();
my $osModule = 'WPControl::Install::' . $os;
eval "use $osModule qw(install_system_dependencies install_openresty install_php install_perl_modules install_pear install_imagick)";
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
sub install {
    printf "Installing wp-control at: $applicationRoot\n",
    #install_system_dependencies();
    #install_openresty($applicationRoot);
    #install_php($applicationRoot);
    #install_perl_modules();
    install_pear($applicationRoot);
    install_imagick($applicationRoot);
}
