#!/usr/bin/perl

package WPControl::Install::OpenSUSE;

use strict;
use Cwd qw(getcwd abs_path);
use File::Basename;
use lib dirname(abs_path(__FILE__)) . "/modules";
use WPControl::Utility qw(command_result);
use WPControl::System qw(how_many_threads_should_i_use);
use Exporter 'import';

our @EXPORT_OK = qw(install_system_dependencies install_php);

my @systemDependencies = qw(
    supervisor authbind expect openssl intltool autoconf automake
    gcc gcc-c++ libstdc++-devel curl pkg-config perl-App-cpanminus
    ncurses-devel libpcre2-devel libcurl-devel ImageMagick-devel
    libopenssl-devel libxslt-devel mysql-community-devel libxml2-devel
    libicu-devel ImageMagick-c++-devel libzip-devel oniguruma-devel
    libsodium-devel glib2-devel libwebp-devel mysql-community-server
    imagemagick zip
);

# ====================================
# Subroutines
# ====================================

# Installs OS-level system dependencies.
sub install_system_dependencies {
    my $username = getpwuid($<);
    print "sudo privileges required to install system dependencies.\n";
    print "Please enter password for user '$username':\n";

    my @installCmd = (
        'sudo', 'zypper', '--non-interactive', 'install',
        @systemDependencies
    );
    system(@installCmd);
    command_result($?, $!, "Installed openSUSE dependencies...", \@installCmd);
}

# Installs PHP using system default compiler.
sub install_php {
    my ($dir) = @_;
    my $threads = how_many_threads_should_i_use();

    my @configurePhp = (
        './configure',
        '--prefix=' . $dir . '/opt/php',
        '--sysconfdir=' . $dir . '/etc',
        '--with-config-file-path=' . $dir . '/etc/php',
        '--enable-opcache', '--enable-fpm', '--enable-dom', '--enable-exif',
        '--enable-fileinfo', '--enable-mbstring=shared', '--enable-bcmath',
        '--enable-intl=shared', '--enable-ftp', '--enable-pcntl', '--enable-gd',
        '--enable-soap', '--enable-sockets', '--without-sqlite3', '--without-pdo-sqlite',
        '--with-libxml', '--with-xsl', '--with-xmlrpc', '--with-zlib',
        '--with-curl', '--with-webp', '--with-openssl', '--with-zip', '--with-bz2',
        '--with-sodium', '--with-mysqli', '--with-pdo-mysql', '--with-mysql-sock',
        '--with-iconv'
    );

    my $orig = getcwd();
    my ($archive) = glob("$dir/opt/php-*.tar.gz");
    die "PHP archive not found: $dir/opt/php-*.tar.gz\n" unless $archive && -e $archive;

    system('tar', '-xzf', $archive, '-C', "$dir/opt/");
    command_result($?, $!, 'Unpacked PHP archive', ['tar', '-xzf', $archive, '-C', "$dir/opt/"]);

    chdir glob("$dir/opt/php-*/");
    system(@configurePhp);
    command_result($?, $!, 'PHP configured', \@configurePhp);

    print "Compiling PHP with $threads threads...\n";
    system('make', "-j$threads");
    command_result($?, $!, 'PHP built', 'make');

    system('make', 'install');
    command_result($?, $!, 'PHP installed', 'make install');

    chdir $orig;
}

1;
