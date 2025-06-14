#!/usr/bin/perl

package WPControl::Install::Fedora;

use strict;
use Cwd qw(getcwd abs_path);
use File::Basename;
use lib dirname(abs_path(__FILE__)) . "/modules";
use WPControl::Utility qw(command_result);
use WPControl::System qw(how_many_threads_should_i_use);
use Exporter 'import';

our @EXPORT_OK = qw(install_system_dependencies install_php);

my @systemDependencies = qw(
    supervisor authbind expect openssl intltool autoconf
    automake gcc gcc-c++ libstdc++-devel curl pkgconfig cpanminus
    ncurses-devel pcre-devel libcurl-devel ImageMagick-devel
    openssl-devel libxslt-devel mysql-devel libxml2 libxml2-devel
    libicu-devel ImageMagick-c++-devel libzip-devel oniguruma-devel
    libsodium-devel glib2-devel libwebp-devel mysql mysql-server
    imagemagick zip
);

# ====================================
# Subroutines
# ====================================

# Installs OS-level system dependencies.
sub install_system_dependencies {
    my $username = getpwuid($<);
    print "Root privileges required for installing system dependencies.\n";
    print "Please enter your password for sudo:\n";

    # Install Development Tools group and the rest
    my @installCmd = (
        'sudo', 'dnf', 'install', '-y',
        '@development-tools',
        @systemDependencies
    );
    system(@installCmd);
    command_result($?, $!, "Installed group + system dependencies...", \@installCmd);
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

    my $originalDir = getcwd();

    # Unpack PHP Archive
    my ($archive) = glob("$dir/opt/php-*.tar.gz");

    unless ($archive && -e $archive) {
        die "PHP archive not found: $dir/opt/php-*.tar.gz\n";
    }

    system('tar', '-xzf', $archive, '-C', "$dir/opt/");
    command_result($?, $!, 'Unpacked PHP Archive...', ['tar', '-xzf', $archive, '-C', "$dir/opt/"]);

    chdir glob("$dir/opt/php-*/");

    # Configure PHP
    system(@configurePhp);
    command_result($?, $!, 'Configured PHP...', \@configurePhp);

    # Make and Install PHP
    print "\n=================================================================\n";
    print " Compiling PHP...\n";
    print "=================================================================\n\n";
    print "Running make using $threads threads in concurrency.\n\n";

    system('make', "-j$threads");
    command_result($?, $!, 'Made PHP...', 'make');

    system('make', 'install');
    command_result($?, $!, 'Installed PHP...', 'make install');

    chdir $originalDir;
}

1;
