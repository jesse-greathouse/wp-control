#!/usr/bin/perl

package WPControl::Install::Alpine;

use strict;
use warnings;
use Cwd qw(getcwd abs_path);
use File::Basename;
use lib dirname(abs_path(__FILE__)) . "/modules";
use WPControl::Utility qw(command_result);
use WPControl::System qw(how_many_threads_should_i_use);
use Exporter 'import';

our @EXPORT_OK = qw(install_system_dependencies install_php);

# Alpine package list
my @systemDependencies = qw(
    supervisor authbind expect openssl openssl-dev
    curl curl-dev pkgconfig build-base
    perl-app-cpanminus ncurses-dev pcre2-dev libxml2-dev
    icu-dev libzip-dev oniguruma-dev libsodium-dev
    glib2-dev libwebp-dev mariadb-dev imagemagick-dev zip
);

# Installs OS-level system dependencies.
sub install_system_dependencies {
    my $username = getpwuid($<);
    print "sudo privileges required to install dependencies on Alpine.\n";
    print "Please enter password for '$username':\n";

    my @installCmd = (
        'sudo', 'apk', 'add', '--no-cache',
        @systemDependencies
    );
    system(@installCmd);
    command_result($?, $!, "Installed Alpine system dependencies...", \@installCmd);
}

# Installs PHP using system default compiler (same as Debian/Fedora code).
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
    die "PHP archive not found: $dir/opt/php-*.tar.gz\n"
      unless $archive && -e $archive;

    system('tar', '-xzf', $archive, '-C', "$dir/opt/");
    command_result($?, $!, 'Unpacked PHP archive...', ['tar','-xzf',$archive,'-C',"$dir/opt/"]);

    chdir glob("$dir/opt/php-*/");
    system(@configurePhp);
    command_result($?, $!, 'Configured PHP...', \@configurePhp);

    print "Compiling PHP using $threads threads...\n";
    system('make', "-j$threads");
    command_result($?, $!, 'Compiled PHP...', 'make');

    system('make', 'install');
    command_result($?, $!, 'Installed PHP...', 'make install');

    chdir $orig;
}

1;
