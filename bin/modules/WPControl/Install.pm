#!/usr/bin/perl

package WPControl::Install;

use strict;
use File::Basename;
use File::Copy;
use File::Path qw(make_path rmtree);
use Getopt::Long;
use Cwd qw(getcwd abs_path);
use lib(dirname(abs_path(__FILE__))  . "/modules");
use WPControl::Utility qw(
    str_replace_in_file
    get_operating_system
    command_result
);
use WPControl::System qw(how_many_threads_should_i_use);
use Exporter 'import';
our @EXPORT_OK = qw(install install_help);

my $binDir = abs_path(dirname(__FILE__) . '/../../');
my $applicationRoot = abs_path(dirname($binDir));
my $os = get_operating_system();
my $osModule = 'WPControl::Install::' . $os;
my $nodeVersion = '22.14';
my $npmVersion = '11.2.0';
my $phpredisVersion = '6.2.0';
my $imagickVersion = '3.8.0';

eval "use $osModule qw(install_system_dependencies install_php)";

my @perlModules = (
    'JSON',
    'Archive::Zip',
    'Bytes::Random::Secure',
    'Config::File',
    'LWP::Protocol::https',
    'LWP::UserAgent',
    'File::Slurper',
    'File::HomeDir',
    'File::Find::Rule',
    'File::Touch',
    'Sys::Info',
    'Term::ANSIScreen',
    'Term::Menus',
    'Term::Prompt',
    'Term::ReadKey',
    'Text::Wrap',
    'YAML::XS',
);

# ====================================
#    Subroutines below this point
# ====================================

# Displays help for available install options.
sub install_help {
    print <<'EOF';
Usage: install [--option ...]

Installs WPControl and its dependencies. By default, runs a full install unless specific components are requested.

Examples:
  install                     # Full install (all components)
  install --php               # Install only PHP
  install --skip-node         # Install everything except Node.js
  install --php --composer    # Install only PHP and Composer

 Available options:
  --system           Install OS-level dependencies
  --node             Install Node.js and run frontend build
  --perl             Install Perl modules
  --openresty        Install and configure OpenResty
  --php              Install PHP, configure php.ini, and PHP extensions
  --wordpress        Install WordPress components
  --composer         Install Composer and PHP packages

 Skip options:
  --skip-system      Skip OS-level dependency installation
  --skip-node        Skip Node.js and frontend build
  --skip-perl        Skip Perl module installation
  --skip-openresty   Skip OpenResty setup
  --skip-php         Skip PHP installation and config
  --skip-wordpress   Skip WordPress components
  --skip-composer    Skip Composer and PHP packages

EOF
}

# Performs the install routine.
sub install {
    printf "Installing WPControl at: $applicationRoot\n",

    my %options = handle_options();

    if ($options{'system'}) {
        install_system_dependencies();
    }

    if ($options{'perl'}) {
        install_perl_modules();
    }

    if ($options{'openresty'}) {
        install_openresty($applicationRoot);
    }

    if ($options{'php'}) {
        configure_php($applicationRoot);
        install_php($applicationRoot);
        install_phpredis($applicationRoot);
        install_imagick($applicationRoot);
    }

    if ($options{'composer'}) {
        install_composer($applicationRoot);
    }

    if ($options{'wordpress'}) {
        install_wordpress_cli($applicationRoot);
    }

    if ($options{'node'}) {
        install_node($applicationRoot);
    }

    install_symlinks($applicationRoot);

    cleanup($applicationRoot);
}

sub handle_options {
    my $defaultInstall = 1;
    my @components =  ('system', 'node', 'perl', 'openresty', 'php', 'wordpress', 'composer');
    my %skips;
    my %installs;

    GetOptions(
        "skip-system"    => \$skips{'system'},
        "skip-node"      => \$skips{'node'},
        "skip-openresty" => \$skips{'openresty'},
        "skip-perl"      => \$skips{'perl'},
        "skip-php"       => \$skips{'php'},
        "skip-wordpress" => \$skips{'wordpress'},
        "skip-composer"  => \$skips{'composer'},
        "system"         => \$installs{'system'},
        "node"           => \$installs{'node'},
        "openresty"      => \$installs{'openresty'},
        "perl"           => \$installs{'perl'},
        "php"            => \$installs{'php'},
        "wordpress"      => \$installs{'wordpress'},
        "composer"       => \$installs{'composer'},
    ) or do {
        print "Invalid install option.\n";
        install_help();
        exit(1);
    };

    # If any of the components are requested for install...
    foreach (@components) {
        if (defined $installs{$_}) {
            $defaultInstall = 0;
            last;
        }
    }

    # If invalid mix of flags was supplied (e.g., nothing valid at all)
    if (!$defaultInstall && !grep { $installs{$_} } @components) {
        print "No valid components selected for install.\n";
        install_help();
        exit(1);
    }

    # Set up an options hash with the default install flag.
    my  %options = (
        system      => $defaultInstall,
        node        => $defaultInstall,
        openresty   => $defaultInstall,
        perl        => $defaultInstall,
        php         => $defaultInstall,
        wordpress   => $defaultInstall,
        composer    => $defaultInstall
    );

    # If the component is listed on the command line...
    # Set the option for true.
    foreach (@components) {
        if (defined $installs{$_}) {
            $options{$_} = 1;
        }
    }

    # If the component is set to skip on the command line...
    # Set the option for false.
    foreach (@components) {
        if (defined $skips{$_}) {
            $options{$_} = 0;
        }
    }

    return %options;
}

sub install_openresty {
    my ($dir) = @_;
    my $threads = how_many_threads_should_i_use();
    my @configureOpenresty = ('./configure');
    push @configureOpenresty, '--prefix=' . $dir . '/opt/openresty';
    push @configureOpenresty, '--with-pcre-jit';
    push @configureOpenresty, '--with-ipv6';
    push @configureOpenresty, '--with-http_iconv_module';
    push @configureOpenresty, '--with-http_realip_module';
    push @configureOpenresty, '--with-http_ssl_module';
    push @configureOpenresty, "-j$threads";

    my $originalDir = getcwd();

    # Unpack
    my ($archive) = glob("$dir/opt/openresty-*.tar.gz");

    unless ($archive && -e $archive) {
        die "OpenResty archive not found: $dir/opt/openresty-*.tar.gz\n";
    }

    system('tar', '-xzf', $archive, '-C', "$dir/opt/");
    command_result($?, $!, 'Unpack Nginx (Openresty)... Archive...', ['tar', '-xzf', $archive, '-C', "$dir/opt/"]);


    chdir glob("$dir/opt/openresty-*/");

    # configure
    system(@configureOpenresty);
    command_result($?, $!, 'Configure Nginx (Openresty)......', \@configureOpenresty);

    # Make and Install Nginx(Openresty)
    print "\n=================================================================\n";
    print " Compiling Nginx...\n";
    print "=================================================================\n\n";
    print "Running make using $threads threads in concurrency.\n\n";

    system('make', "-j$threads");
    command_result($?, $!, 'Compile Nginx (Openresty)...', "make -j$threads");

    # install OpenResty core
    system(('make', 'install'));
    command_result($?, $!, 'Install (Openresty)...', 'make install');

    chdir $originalDir;
}

# configures PHP.
sub configure_php {
    my ($dir) = @_;
    my $etcDir = $dir . '/etc';
    my $optDir = $dir . '/opt';
    my $phpExecutable = "$optDir/php/bin/php";
    my $phpIniFile = "$etcDir/php/php.ini";
    my $phpIniDist = "$etcDir/php/php.dist.ini";
    my $phpFpmConfFile = "$etcDir/php-fpm.d/php-fpm.conf";
    my $phpFpmConfDist = "$etcDir/php-fpm.d/php-fpm.dist.conf";

    copy($phpIniDist, $phpIniFile) or die "Copy $phpIniDist failed: $!";
    copy($phpFpmConfDist, $phpFpmConfFile) or die "Copy $phpFpmConfDist failed: $!";
    str_replace_in_file('__DIR__', $dir, $phpIniFile);
    str_replace_in_file('__DIR__', $dir, $phpFpmConfFile);
    str_replace_in_file('__APP_NAME__', 'WPControl', $phpFpmConfFile);
    str_replace_in_file('__USER__', $ENV{"LOGNAME"}, $phpFpmConfFile);
}

# installs symlinks.
sub install_symlinks {
    my ($dir) = @_;
    my $optDir = $dir . '/opt';

    unlink "$binDir/php";
    symlink("$optDir/php/bin/php", "$binDir/php");
}

# Installs Perl Modules.
sub install_perl_modules {
    foreach my $perlModule (@perlModules) {
        my @cmd = ('sudo', 'cpanm', $perlModule);
        system(@cmd);
        command_result($?, $!, "Install Perl Module: $perlModule", \@cmd);
    }
}

# installs phpredis.
sub install_phpredis {
    my ($dir) = @_;
    my $threads = how_many_threads_should_i_use();
    my $optDir = $dir . '/opt';
    my $phpizeBinary = $optDir . '/php/bin/phpize';
    my $phpconfigBinary = $optDir . '/php/bin/php-config';
    my $phpredisRepo = 'https://github.com/phpredis/phpredis.git';
    my $originalDir = getcwd();

    chdir glob("$optDir");

    # Configure Command
    my @phpredisConfigure = ('./configure');
    push @phpredisConfigure, '--prefix=' . $optDir;
    push @phpredisConfigure, '--with-php-config=' . $phpconfigBinary;

    # Delete Repo Command
    my @phpredisDeleteRepo = ('rm');
    push @phpredisDeleteRepo, '-rf';
    push @phpredisDeleteRepo, "$optDir/phpredis";

    system("git clone --depth 1 --branch $phpredisVersion $phpredisRepo");

    chdir glob("$optDir/phpredis");

    system($phpizeBinary);
    command_result($?, $!, 'phpize...', \$phpizeBinary);

    system(@phpredisConfigure);
    command_result($?, $!, 'Configuring phpredis...', \@phpredisConfigure);

    # Make and Install phpredis
    print "\n=================================================================\n";
    print " Compiling phpredis Extension...\n";
    print "=================================================================\n\n";
    print "Running make using $threads threads in concurrency.\n\n";

    system('make', "-j$threads");
    command_result($?, $!, 'make phpredis...', "make -j$threads");

    system('make install');
    command_result($?, $!, 'make install phpredis', 'make install');

    chdir glob("$originalDir");

    system(@phpredisDeleteRepo);
    command_result($?, $!, 'Deleting phpredis repo...', \@phpredisDeleteRepo);
}

# installs Imagemagick.
sub install_imagick {
    my ($dir) = @_;
    my $threads = how_many_threads_should_i_use();
    my $optDir = $dir . '/opt';
    my $phpizeBinary = $optDir . '/php/bin/phpize';
    my $phpconfigBinary = $optDir . '/php/bin/php-config';
    my $imagickRepo = 'https://github.com/Imagick/imagick';
    my $originalDir = getcwd();

    chdir glob("$optDir");

    system("git clone --depth 1 --branch $imagickVersion $imagickRepo");

    chdir glob("$optDir/imagick");

    system("$phpizeBinary && ./configure --prefix=$optDir --with-php-config=$phpconfigBinary");

    # Make and Install imagick
    print "\n=================================================================\n";
    print " Compiling imagick Extension...\n";
    print "=================================================================\n\n";
    print "Running make using $threads threads in concurrency.\n\n";

    system('make', "-j$threads");
    command_result($?, $!, 'make imagick...', "make -j$threads");

    system('make install');
    command_result($?, $!, 'make install imagick', 'make install');

    chdir glob("$originalDir");

    system("rm -rf $optDir/imagick");
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

sub install_wordpress_cli {
    my ($dir) = @_;
    my $binDir     = "$dir/bin";
    my $vendorDir  = "$dir/web/vendor";
    my $composer   = "$binDir/composer";
    my $php        = "$dir/opt/php/bin/php";

    # Ensure vendor dir exists
    make_path($vendorDir) unless -d $vendorDir;

    # Install wp-cli/wp-cli using project-local composer
    print "Installing wp-cli/wp-cli locally with Composer...\n";
    system($php, $composer, 'require', 'wp-cli/wp-cli-bundle', "--working-dir=$dir/web");
    command_result($?, $!, 'Install wp-cli/wp-cli...', "$php $composer require wp-cli/wp-cli --working-dir=$dir/web");
}

# installs Composer.
sub install_composer {
    my ($dir) = @_;
    my $phpExecutable = $dir . '/opt/php/bin/php';
    my $composerInstallScript = $binDir . '/composer-setup.php';
    my $composerHash = 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6';
    my $composerDownloadCommand = "$phpExecutable -r \"copy('https://getcomposer.org/installer', '$composerInstallScript');\"";
    my $composerCheckHashCommand = "$phpExecutable -r \"if (hash_file('sha384', '$composerInstallScript') === '$composerHash') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('$composerInstallScript'); } echo PHP_EOL;\"";
    my $composerInstallCommand = "$phpExecutable $composerInstallScript --filename=composer";
    my $removeIntallScriptCommand = "$phpExecutable -r \"unlink('$composerInstallScript');\"";
    my $composerArtifact = "composer";

    # Remove the composer artifact if it already exists.
    if (-e "$binDir/$composerArtifact") {
         unlink "$binDir/$composerArtifact";
    }

    system(('bash', '-c', $composerDownloadCommand));
    command_result($?, $!, 'Download Composer Install Script...', $composerDownloadCommand);

    system(('bash', '-c', $composerCheckHashCommand));
    command_result($?, $!, 'Verify Composer Hash...', $composerCheckHashCommand);

    system(('bash', '-c', $composerInstallCommand));
    command_result($?, $!, 'Installing Composer...', $composerInstallCommand);

    system(('bash', '-c', $removeIntallScriptCommand));
    command_result($?, $!, 'Removing Composer Install Script...', $removeIntallScriptCommand);

    # Move the composer artifact to the right place in bin/
    if (-e $composerArtifact) {
         move($composerArtifact, "$binDir/$composerArtifact");
    }
}

# installs composer dependencies.
sub install_composer_dependencies {
    my ($dir) = @_;
    my $originalDir = getcwd();
    my $srcDir = $dir . '/web';
    my $vendorDir = $srcDir . '/vendor';
    my $phpExecutable = $dir . '/opt/php/bin/php';
    my $composerExecutable = "$phpExecutable $binDir/composer";
    my $composerInstallCommand = "$composerExecutable install";

    chdir $srcDir;

    # If elixir directory exists, delete it.
    if (-d $vendorDir) {
        system('rm', '-rf', $vendorDir);
        command_result($?, $!, "Removing existing composer vendors directory...", "rm -rf $vendorDir");
    }

    system(('bash', '-c', $composerInstallCommand));
    command_result($?, $!, 'Installing Composer Dependencies...', $composerInstallCommand);

    chdir $originalDir
}

sub cleanup {
    my ($dir) = @_;
    my $phpBuildDir = glob("$dir/opt/php-*/");
    my $openrestyBuildDir = glob("$dir/opt/openresty-*/");
    system('rm', '-rf', $phpBuildDir);
    command_result($?, $!, 'Remove PHP Build Dir...', "rm -rf $phpBuildDir");
    system('rm', '-rf', $openrestyBuildDir);
    command_result($?, $!, 'Remove Openresty Build Dir...', "rm -rf $openrestyBuildDir");
}

sub install_node {
    my ($dir) = @_;
    my $nvmDir = "$dir/.nvm";
    my $nvmInstallScript = 'https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh';

    # Check if NVM is already installed
    my $nvmCheck = `bash -c 'export NVM_DIR=\$HOME/.nvm && [ -s "\$NVM_DIR/nvm.sh" ] && source \$NVM_DIR/nvm.sh && command -v nvm'`;
    chomp $nvmCheck;

    unless ($nvmCheck) {
        unless (-d $nvmDir) {
            system('bash', '-c', "curl -o- $nvmInstallScript | bash");
            command_result($?, $!, 'Installing NVM...', "curl -o- $nvmInstallScript | bash");
        }
    }

    # Ensure Node.js version is installed
    system('bash', '-c', "export NVM_DIR=\$HOME/.nvm && source \$NVM_DIR/nvm.sh && nvm install $nodeVersion");
    command_result($?, $!, "Installing Node.js $nodeVersion via NVM...", "nvm install $nodeVersion");

    # Use the correct Node.js version and upgrade NPM afterward
    my $bash_cmd = <<BASH;
export NVM_DIR=\$HOME/.nvm
source \$NVM_DIR/nvm.sh
nvm use $nodeVersion
npm install -g npm\@$npmVersion
BASH

    system('bash', '-c', $bash_cmd);
    command_result($?, $!, "Switching to Node.js $nodeVersion and upgrading npm to $npmVersion...", "nvm use $nodeVersion && npm install -g npm\@$npmVersion");
}

sub node_build {
    my ($dir) = @_;
    my $originalDirectory = getcwd();
    my $srcDir = "$dir/web";
    my $modulesDir = $srcDir . '/node_modules';
    my $nvm_env = "export NVM_DIR=\$HOME/.nvm && source \$NVM_DIR/nvm.sh && nvm use $nodeVersion";

    # Change to project source dir
    chdir($srcDir) or die "Failed to change directory to $srcDir: $!";

    # Remove node_modules if present
    if (-d $modulesDir) {
        system('rm', '-rf', $modulesDir);
        command_result($?, $!, "Removing existing node_modules...", "rm -rf $modulesDir");
    }

    # Log version info with correct shell
    system('bash', '-c', "$nvm_env && node -v && npm -v");

    # Run npm install with proper NVM environment
    system('bash', '-c', "$nvm_env && npm install");
    command_result($?, $!, "Installing dependencies...", "npm install");

    # Run npm build
    system('bash', '-c', "$nvm_env && npm run build");
    command_result($?, $!, "Building project...", "npm run build");

    # Restore working directory
    chdir($originalDirectory) or die "Failed to change back to $originalDirectory: $!";
}
