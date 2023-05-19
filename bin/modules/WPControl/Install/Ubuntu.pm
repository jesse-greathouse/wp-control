#!/usr/bin/perl

package WPControl::Install::Ubuntu;
use strict;
use Cwd qw(getcwd abs_path);
use File::Copy;
use Exporter 'import';
our @EXPORT_OK = qw(
    install_system_dependencies 
    install_openresty 
    install_php 
    install_perl_modules 
    install_pear 
    install_imagick
    install_wordpress
    install_wordpress_skeleton
    install_cli
    cleanup
);

my @systemDependencies = (
    'supervisor',
    'authbind',
    'expect',
    'openssl',
    'build-essential',
    'intltool',
    'autoconf',
    'automake',
    'gcc',
    'perl',
    'curl',
    'pkg-config',
    'expect',
    'cpanminus',
    'mysql-client',
    'imagemagick',
    'libpcre++-dev',
    'libcurl4',
    'libcurl4-openssl-dev',
    'libmagickwand-dev',
    'libssl-dev',
    'libxslt1-dev',
    'libmysqlclient-dev',
    'libpcre2-dev',
    'libxml2',
    'libxml2-dev',
    'libicu-dev',
    'libmagick++-dev',
    'libzip-dev',
    'libonig-dev',
    'libsodium-dev',
    'libglib2.0-dev',
    
);

my @perlModules = (
    'JSON',
    'YAML::XS',
    'LWP::UserAgent',
    'cpanm LWP::Protocol::https',
    'Term::ANSIScreen',
    'Term::Menus',
    'Term::Prompt',
    'Term::ReadKey',
    'Text::Wrap',
    'Archive::Zip',
    'File::Slurper',
    'File::HomeDir',
    'File::Find::Rule',
);

1;

# ====================================
#    Subroutines below this point
# ====================================

# installs OS level system dependencies.
sub install_system_dependencies {
    my @updateCmd = ('sudo');
    push @updateCmd, 'apt-get';
    push @updateCmd, 'update';
    system(@updateCmd);
    command_result($?, $!, "Updating system dependencies...", \@updateCmd);

    my @cmd = ('sudo');
    push @cmd, 'apt-get';
    push @cmd, 'install';
    push @cmd, '-y';
    foreach my $dependency (@systemDependencies) {
        push @cmd, $dependency;
    }

    system(@cmd);
    command_result($?, $!, "Install system dependencies...", \@cmd);
}

# installs Openresty.
sub install_openresty {
    my ($dir) = @_;
    my @configureOpenresty = ('./configure');
    push @configureOpenresty, '--prefix=' . $dir . '/opt/openresty';
    push @configureOpenresty, '--with-pcre-jit';
    push @configureOpenresty, '--with-ipv6';
    push @configureOpenresty, '--with-http_iconv_module';
    push @configureOpenresty, '--with-http_realip_module';
    push @configureOpenresty, '--with-http_ssl_module';
    push @configureOpenresty, '-j2';

    my $originalDir = getcwd();

    # Unpack
    system(('bash', '-c', "tar -xzf $dir/opt/openresty-*.tar.gz -C $dir/opt/"));
    command_result($?, $!, 'Unpack Openresty Archive...', 'tar -xzf ' . $dir . '/opt/openresty-*.tar.gz -C ' . $dir . ' /opt/');
    
    chdir glob("$dir/opt/openresty-*/");

    # configure
    system(@configureOpenresty);
    command_result($?, $!, 'Configure Openresty...', \@configureOpenresty);

    # make
    system('make');
    command_result($?, $!, 'Make Openresty...', 'make');

    # install
    system(('make', 'install'));
    command_result($?, $!, 'Install Openresty...', 'make install');

    chdir $originalDir;
}

# installs PHP.
sub install_php {
    my ($dir) = @_;
    my @configurePhp = ('./configure');
    push @configurePhp, '--prefix=' . $dir . '/opt/php';
    push @configurePhp, '--sysconfdir=' . $dir . '/etc',;
    push @configurePhp, '--with-config-file-path=' . $dir . '/etc/php',;
    push @configurePhp, '--with-config-file-scan-dir=' . $dir . '/etc/php/conf.d';
    push @configurePhp, '--enable-opcache';
    push @configurePhp, '--enable-fpm';
    push @configurePhp, '--enable-dom';
    push @configurePhp, '--enable-exif';
    push @configurePhp, '--enable-fileinfo';
    push @configurePhp, '--enable-json';
    push @configurePhp, '--enable-mbstring';
    push @configurePhp, '--enable-bcmath';
    push @configurePhp, '--enable-intl';
    push @configurePhp, '--enable-ftp';
    push @configurePhp, '--without-sqlite3';
    push @configurePhp, '--without-pdo-sqlite';
    push @configurePhp, '--with-libxml';
    push @configurePhp, '--with-xsl';
    push @configurePhp, '--with-xmlrpc';
    push @configurePhp, '--with-zlib';
    push @configurePhp, '--with-curl';
    push @configurePhp, '--with-webp';
    push @configurePhp, '--with-openssl';
    push @configurePhp, '--with-zip';
    push @configurePhp, '--with-sodium';
    push @configurePhp, '--with-mysqli';
    push @configurePhp, '--with-pdo-mysql';
    push @configurePhp, '--with-mysql-sock';
    push @configurePhp, '--with-iconv';

    my $originalDir = getcwd();
   
    # Unpack
    system(('bash', '-c', "tar -xzf $dir/opt/php-*.tar.gz -C $dir/opt/"));
    command_result($?, $!, 'Unpack PHP Archive...', 'tar -xf ' . $dir . '/opt/php-*.tar.gz -C ' . $dir . ' /opt/');

    chdir glob("$dir/opt/php-*/");

    # configure
    system(@configurePhp);
    command_result($?, $!, 'Configure PHP...', \@configurePhp);

    # make
    system('make');
    command_result($?, $!, 'Make PHP...', 'make');

    # install
    system('make install');
    command_result($?, $!, 'Install PHP...', 'make install');

    chdir $originalDir;
}

# installs Perl Modules.
sub install_perl_modules {
    foreach my $perlModule (@perlModules) {
        my @cmd = ('sudo');
        push @cmd, 'cpanm';
        push @cmd, $perlModule;
        system(@cmd);

        command_result($?, $!, "Shared library pass for: $_", \@cmd);
    }
}

# installs Pear.
sub install_pear {
    my ($dir) = @_;
    my $phpIniFile = $dir . '/etc/php/php.ini';
    my $phpIniBackupFile = $phpIniFile . '.' . time() . '.bak';

    # If php.ini exists, hide it before pear installs
    if (-e $phpIniFile) {
        move($phpIniFile, $phpIniBackupFile);
    }

    system(('bash', '-c', "yes n | $dir/bin/install-pear.sh $dir/opt"));
    command_result($?, $!, 'Install Pear...', "yes n | $dir/bin/install-pear.sh $dir/opt");

    # Replace the php.ini file
    if (-e $phpIniBackupFile) {
         move($phpIniBackupFile, $phpIniFile);
    }
}

# installs Imagemagick.
sub install_imagick {
    my ($dir) = @_;
    my $phpIniFile = $dir . '/etc/php/php.ini';
    my $phpIniBackupFile = $phpIniFile . '.' . time() . '.bak';
    my $cmd = 'yes n | PATH="' . $dir . '/opt/php/bin:$PATH" ' . $dir . '/opt/pear/bin/pecl install imagick';

    # If php.ini exists, hide it before pear installs
    if (-e $phpIniFile) {
        move($phpIniFile, $phpIniBackupFile);
    }

    system(('bash', '-c', $cmd));
    command_result($?, $!, 'Install Imagemagick...', "...");

    # Replace the php.ini file
    if (-e $phpIniBackupFile) {
         move($phpIniBackupFile, $phpIniFile);
    }
}

# installs WordPress
sub install_wordpress {
    my ($dir) = @_;
    my $originalDir = getcwd();

    chdir "$dir/bin";
    system(('bash', '-c', "OPT=$dir/opt WEB=$dir/web $dir/bin/install-wordpress.pl"));
    command_result($?, $!, 'Install WordPress...', "OPT=$dir/opt WEB=$dir/web $dir/bin/install-wordpress.pl");
    chdir $originalDir;
}

# installs WordPress Skeleton
sub install_wordpress_skeleton {
    my ($dir) = @_;
    my $originalDir = getcwd();

    chdir "$dir/bin";
    system(('bash', '-c', "DIR=$dir $dir/bin/install-wp-skeleton.pl"));
    command_result($?, $!, 'Install WordPress Skeleton...', "DIR=$dir $dir/bin/install-wp-skeleton.pl");
    chdir $originalDir;
}

sub install_cli {
    my ($dir) = @_;
    my $cliFile = $dir . '/bin/wp-cli.phar';
    my $cliSourceUrl = 'https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar';

    # If cli executable exists, remove it
    if (-e $cliFile) {
        unlink($cliFile);
    }

    system(('bash', '-c', "curl -o $cliFile $cliSourceUrl"));
    command_result($?, $!, 'Install WordPress CLI...', "curl -o $cliFile $cliSourceUrl");
    system(('bash', '-c', "chmod +x  $cliFile"));
    command_result($?, $!, 'Set Permissions on WordPress CLI...', "chmod +x  $cliFile");
}

sub cleanup {
    my ($dir) = @_;
    my $phpBuildDir = glob("$dir/opt/php-*/");
    my $openrestyBuildDir = glob("$dir/opt/openresty-*/");
    my $wordpressArchive = glob("$dir/opt/wordpress-*.zip");
    system(('bash', '-c', "rm -rf $phpBuildDir"));
    command_result($?, $!, 'Remove PHP Build Dir...', "rm -rf $phpBuildDir");
    system(('bash', '-c', "rm -rf $openrestyBuildDir"));
    command_result($?, $!, 'Remove Openresty Build Dir...', "rm -rf $openrestyBuildDir");
    system(('bash', '-c', "rm -rf $wordpressArchive"));
    command_result($?, $!, 'Remove WordPress Build Tarball...', "rm $wordpressArchive");
}

sub command_result {
    my ($exit, $err, $operation_str, @cmd) = @_;

    if ($exit == -1) {
        print "failed to execute: $err \n";
        exit $exit;
    }
    elsif ($exit & 127) {
        printf "child died with signal %d, %s coredump\n",
            ($exit & 127),  ($exit & 128) ? 'with' : 'without';
        exit $exit;
    }
    else {
        printf "$operation_str exited with value %d\n", $exit >> 8;
    }
}
