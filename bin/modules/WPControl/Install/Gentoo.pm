#!/usr/bin/perl

package WPControl::Install::Gentoo;

use strict;
use warnings;
use Cwd qw(getcwd abs_path);
use File::Basename;
use lib dirname(abs_path(__FILE__)) . "/modules";
use WPControl::Utility qw(command_result);
use WPControl::System qw(how_many_threads_should_i_use);
use Exporter 'import';

our @EXPORT_OK = qw(install_system_dependencies install_php);

my @systemDependencies = qw(
    app-admin/supervisor
    sys-apps/authbind
    sys-process/expect
    dev-libs/openssl
    dev-lang/perl
    dev-perl/App-cpanminus
    sys-devel/autoconf
    sys-devel/automake
    sys-devel/gcc
    sys-devel/binutils
    dev-libs/ncurses
    dev-libs/pcre
    net-misc/curl
    >=dev-libs/libxml2-2.9.0
    sys-devel/pkgconf
    dev-libs/icu
    media-libs/libwebp
    dev-libs/libzip
    dev-libs/oniguruma
    dev-libs/libsodium
    dev-libs/glib
    dev-db/mariadb
    media-libs/imagemagick
    app-arch/zip
);

# ====================================
# Subroutines
# ====================================

# Install system dependencies using Portage
sub install_system_dependencies {
    my $username = getpwuid($<);
    print "Root privileges required for installing dependencies on Gentoo.\n";
    print "Please enter password for user '$username':\n";

    my @installCmd = (
        'sudo', 'emerge', '--update', '--newuse', '--quiet-build',
        join(' ', @systemDependencies)
    );
    system(@installCmd);
    command_result($?, $!, "Installed Gentoo system dependencies...", \@installCmd);
}

# Build PHP from source using system compiler
sub install_php {
    my ($dir) = @_;
    my $threads = how_many_threads_should_i_use();

    my @configurePhp = (
        './configure',
        '--prefix=' . $dir . '/opt/php',
        '--sysconfdir=' . $dir . '/etc',
        '--with-config-file-path=' . $dir . '/etc/php',
        '--enable-opcache', '--enable-fpm', '--enable-dom', '--enable-exif',
        '--enable-fileinfo', '--enable-mbstring=shared',
        '--enable-bcmath', '--enable-intl=shared', '--enable-ftp',
        '--enable-pcntl', '--enable-gd', '--enable-soap', '--enable-sockets',
        '--without-sqlite3', '--without-pdo-sqlite', '--with-libxml',
        '--with-xsl', '--with-xmlrpc', '--with-zlib', '--with-curl',
        '--with-webp', '--with-openssl', '--with-zip', '--with-bz2',
        '--with-sodium', '--with-mysqli', '--with-pdo-mysql',
        '--with-mysql-sock', '--with-iconv'
    );

    my $orig = getcwd();
    my ($archive) = glob("$dir/opt/php-*.tar.gz");
    die "PHP archive not found: $dir/opt/php-*.tar.gz\n" unless $archive && -e $archive;

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
