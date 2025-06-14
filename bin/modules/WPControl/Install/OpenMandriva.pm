#!/usr/bin/perl

package WPControl::Install::OpenMandriva;

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
    supervisor authbind expect
    openssl openssl-devel
    intltool autoconf automake
    gcc gcc-c++ libstdc++-devel
    curl curl-devel pkgconfig
    perl-App-cpanminus ncurses-devel
    pcre-devel libcurl-devel
    ImageMagick-devel libxslt-devel
    mariadb-devel libxml2-devel icu-devel
    ImageMagick-c++-devel libzip-devel
    oniguruma-devel libsodium-devel
    glib2-devel libwebp-devel
    mariadb ImageMagick zip
);

sub install_system_dependencies {
    my $username = getpwuid($<);
    print "sudo is required to install dependencies on OpenMandriva.\n";
    print "Please enter password for '$username':\n";

    my @installCmd = (
        'sudo', 'urpmi', '-y',
        @systemDependencies
    );
    system(@installCmd);
    command_result($?, $!, "Installed OpenMandriva dependencies...", \@installCmd);
}

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
        '--without-sqlite3', '--without-pdo-sqlite',
        '--with-libxml', '--with-xsl', '--with-xmlrpc',
        '--with-zlib', '--with-curl', '--with-webp',
        '--with-openssl', '--with-zip', '--with-bz2',
        '--with-sodium', '--with-mysqli', '--with-pdo-mysql',
        '--with-mysql-sock', '--with-iconv'
    );

    my $orig = getcwd();
    my ($archive) = glob("$dir/opt/php-*.tar.gz");
    die "PHP archive not found: $dir/opt/php-*.tar.gz\n" unless $archive && -e $archive;

    system('tar','-xzf',$archive,'-C',"$dir/opt/");
    command_result($?, $!, 'Unpacked PHP...', ['tar','-xzf',$archive,'-C',"$dir/opt/"]);

    chdir glob("$dir/opt/php-*/");
    system(@configurePhp);
    command_result($?, $!, 'Configured PHP...', \@configurePhp);

    print "Compiling PHP with $threads threads…\n";
    system('make', "-j$threads");
    command_result($?, $!, 'Compiled PHP...', 'make');

    system('make','install');
    command_result($?, $!, 'Installed PHP...', 'make install');

    chdir $orig;
}

1;
