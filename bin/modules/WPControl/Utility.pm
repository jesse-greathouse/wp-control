#!/usr/bin/perl

package WPControl::Utility;

use strict;
use Exporter 'import';
use Errno;
use POSIX 'ceil';

# Eagerly install String::Random if it's not available
BEGIN {
    eval {
        require String::Random;
    };
    if ($@) {
        print "📦 String::Random is not installed. Installing via cpanm...\n";
        system('sudo', 'cpanm', '--notest', 'String::Random') == 0
            or die "❌ Failed to install String::Random via cpanm.\n";

        eval {
            require String::Random;
        };
        if ($@) {
            die "❌ Failed to load String::Random after install: $@";
        }
    }
}

our @EXPORT_OK = qw(
  command_result
  get_operating_system
  read_file
  write_file
  trim
  splash
  str_replace_in_file
  generate_rand_str
  is_pid_running
  update_wordpress_user_password
  install_wordpress_database
  is_wordpress_db_installed
  get_wordpress_version
  mysql_dump
  format_backup_label
  wordpress_database_backup
  wordpress_database_restore
  compose_wp_url
  prompt_user_password
  validate_required_fields
  shell_quote
);

# ====================================
#    Subroutines below this point
# ====================================

# Trim the whitespace from a string.
sub trim {
    my $s = shift;
    $s =~ s/^\s+|\s+$//g;
    return $s;
}

sub shell_quote {
    my ($s) = @_;
    $s =~ s/'/'"'"'/g;
    return "'$s'";
}

# Returns string associated with operating system.
sub get_operating_system {
    my %osNames = (
        MSWin32 => 'Win32',
        NetWare => 'Win32',
        symbian => 'Win32',
        darwin  => 'MacOS'
    );

    # Check for Linux-based OS and delegate to a separate function
    if ($^O eq 'linux') {
        return get_linux_distribution();
    }

    # If $^O is not found in the hash, die with an error message
    die "Unsupported operating system: $^O\n" unless exists $osNames{$^O};

    return $osNames{$^O};
}

# Detects the Linux distribution.
sub get_linux_distribution {
    # Arrays for different types of distribution identification
    my @os_release_dists = (
        { pattern => 'rocky',           name => 'Rocky' },
        { pattern => 'ubuntu',          name => 'Ubuntu' },
        { pattern => 'fedora',          name => 'Fedora' },
        { pattern => 'debian',          name => 'Debian' },
        { pattern => 'opensuse',        name => 'OpenSUSE' },
        { pattern => 'arch',            name => 'Arch' },
        { pattern => 'alpine',          name => 'Alpine' },
        { pattern => 'gentoo',          name => 'Gentoo' },
        { pattern => 'openmandriva',    name => 'OpenMandriva' },
    );

    # Check /etc/os-release first (most modern distros)
    if (open my $fh, '<', '/etc/os-release') {
        while (my $line = <$fh>) {
            foreach my $dist (@os_release_dists) {
                if ($line =~ /^ID=$dist->{pattern}/) {
                    return $dist->{name};
                }
            }
        }
    }

    # Fallback to other common files
    if (-e '/etc/lsb-release') {
        if (open my $fh, '<', '/etc/lsb-release') {
            while (my $line = <$fh>) {
                foreach my $dist (@os_release_dists) {
                    if ($line =~ /DISTRIB_ID=$dist->{name}/i) {
                        return $dist->{name};
                    }
                }
            }
        }
    }

    if (-e '/etc/redhat-release') {
        if (open my $fh, '<', '/etc/redhat-release') {
            while (my $line = <$fh>) {
                foreach my $dist (@os_release_dists) {
                    if ($line =~ /$dist->{name}/i) {
                        return $dist->{name};
                    }
                }
            }
        }
    }

    # Check /etc/debian_version for Debian-based distros
    if (-e '/etc/debian_version') {
        return 'Debian';
    }

    # Use uname as a last resort (generic fallback)
    my $uname = `uname -a`;
    foreach my $dist (@os_release_dists) {
        if ($uname =~ /$dist->{name}/i) {
            return $dist->{name};
        }
    }

    # If no distribution was found, throw an error
    die "Unable to determine Linux distribution.\n";
}

# Replaces all occurrences of a string with another string inside a file.
sub str_replace_in_file {
    my ($string, $replacement, $file) = @_;
    my $data = read_file($file);
    $data =~ s/\Q$string/$replacement/g;
    write_file($file, $data);
}

# Reads the contents of a UTF-8 encoded file and returns it as a string.
sub read_file {
    my ($filename) = @_;

    open my $in, '<:encoding(UTF-8)', $filename or die "Could not open '$filename' for reading $!";
    local $/ = undef;
    my $all = <$in>;
    close $in;

    return $all;
}

# Writes a string to a UTF-8 encoded file.
sub write_file {
    my ($filename, $content) = @_;

    open my $out, '>:encoding(UTF-8)', $filename or die "Could not open '$filename' for writing $!";
    print $out $content;
    close $out;

    return;
}

# Handles system command exit status and prints a result message.
sub command_result {
    my ($exit, $err, $operation_str, @cmd) = @_;

    if ($exit == -1) {
        print "Failed to execute command: $err\n";
        print "Command: @cmd\n" if @cmd;
        exit 1;
    }
    elsif ($exit & 127) {
        my $signal = $exit & 127;
        my $coredump = ($exit & 128) ? 'with' : 'without';
        print "Command died with signal $signal ($coredump coredump).\n";
        print "Command: @cmd\n" if @cmd;
        exit 1;
    }
    else {
        my $code = $exit >> 8;
        if ($code != 0) {
            print "Command exited with non-zero status $code.\n";
            print "Command: @cmd\n" if @cmd;
            exit $code;
        }
        else {
            print "$operation_str success!\n";
        }
    }
}

# Generates a random hexadecimal string of a given length (default: 64 characters).
sub generate_rand_str {
    my ($length) = @_;
    $length //= 64;

    # Each byte = 2 hex chars, so we need ceil(length / 2) bytes
    my $bytes_needed = ceil($length / 2);

    open my $urandom, '<:raw', '/dev/urandom' or die "Can't open /dev/urandom: $!";
    read($urandom, my $raw, $bytes_needed) == $bytes_needed or die "Failed to read enough bytes from /dev/urandom";
    close $urandom;

    my $hex = uc unpack('H*', $raw);   # Convert to uppercase hex
    return substr($hex, 0, $length);   # Truncate length
}

# Checks whether a PID from a file is currently running.
sub is_pid_running {
    my ($pidFile) = @_;

    open my $fh, '<', $pidFile or die "Can't open $pidFile: $!";
    my $pid = do { local $/; <$fh> };
    close $fh;

    # Strip whitespace/newlines
    $pid =~ s/^\s+|\s+$//g;

    # Validate PID is numeric
    return 0 unless defined $pid && $pid =~ /^\d+$/;

    my %dispatch = (
        success     => sub { return 1 },
        no_perm     => sub { return 1 },
        not_found   => sub { return 0 },
    );

    my $result = kill(0, $pid);

    return $dispatch{
                    $result             ? 'success' :
                    $! == Errno::EPERM  ? 'no_perm' :
                                        'not_found'
    }->();
}

sub validate_required_fields {
    my ($required_fields_ref, $config_ref) = @_;

    foreach my $field (@$required_fields_ref) {
        my ($domain, $key) = @$field;
        my $value = $config_ref->{$domain}{$key};

        unless (defined $value && $value ne '') {
            die <<"EOF";

❌ Required configuration value missing: [$domain] $key
This value is required and cannot be left blank.

Please run the configuration script again:

  bin/configure

EOF
        }
    }
}

# Updates the password for a WordPress user via wp-cli
sub update_wordpress_user_password {
    use Cwd qw(abs_path);
    use File::Basename qw(dirname);

    my ($user, $new_password) = @_;

    die "Missing required parameter: user"         unless $user;
    die "Missing required parameter: new_password" unless $new_password;

    my $applicationRoot = abs_path(dirname(abs_path(__FILE__)) . '/../../../');
    my $binDir          = "$applicationRoot/bin";
    my $wp_cli_path     = "$binDir/wp";

    my $cmd = join ' ',
        $wp_cli_path,
        'user update',
        shell_quote($user),
        '--user_pass=' . shell_quote($new_password);

    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    if ($output =~ /^Error:/i || $exit_code != 0) {
        die <<"EOF";
❌ Failed to update password for user '$user'.
Command output:
$output
EOF
    }

    print "✅ Password updated successfully for user '$user'.\n";
}

# Installs the WordPress database by invoking wp core install via bin/wp
sub install_wordpress_database {
    use Cwd qw(abs_path);
    use File::Basename qw(dirname);

    my ($url, $title, $admin_user, $admin_email, $admin_password) = @_;

    die "Missing required parameter: url"            unless $url;
    die "Missing required parameter: title"          unless $title;
    die "Missing required parameter: admin_user"     unless $admin_user;
    die "Missing required parameter: admin_email"    unless $admin_email;
    die "Missing required parameter: admin_password" unless $admin_password;

    my $applicationRoot = abs_path(dirname(abs_path(__FILE__)) . '/../../../');
    my $binDir          = "$applicationRoot/bin";
    my $wp_cli_path     = "$binDir/wp";

    my $cmd = join ' ',
        $wp_cli_path,
        "--url=" . shell_quote($url),
        "--title=" . shell_quote($title),
        "--admin_user=" . shell_quote($admin_user),
        "--admin_email=" . shell_quote($admin_email),
        "--admin_password=" . shell_quote($admin_password),
        "--skip-email",
        "core install";

    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    if ($output =~ /^Error:/i || $exit_code != 0) {
        die <<"EOF";
❌ WordPress installation failed.
Command output:
$output
EOF
    }

    print "✅ WordPress database installation succeeded.\n";
}

# Checks if the WordPress database is installed by inspecting the result of `wp db tables`
sub is_wordpress_db_installed {
    use Cwd qw(abs_path);
    use File::Basename qw(dirname);

    my $applicationRoot = abs_path(dirname(abs_path(__FILE__)) . '/../../../');
    my $binDir          = "$applicationRoot/bin";
    my $wp_cli_path     = "$binDir/wp";

    my $cmd = "$wp_cli_path db tables";

    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    if ($output =~ /^Error:/) {
        if ($output =~ /Error:\s+The site you have requested is not installed\./i) {
            return 0;
        } else {
            die "Unexpected error while checking DB install status:\n$output";
        }
    }

    if ($exit_code != 0) {
        die "wp-cli command failed unexpectedly:\n$output";
    }

    return 1;
}

# Returns the current installed WordPress version using wp-cli
sub get_wordpress_version {
    my $applicationRoot = abs_path(dirname(abs_path(__FILE__)) . '/../../../');
    my $binDir          = "$applicationRoot/bin";
    my $wp_cli_path     = "$binDir/wp";

    my $cmd = "$wp_cli_path core version";

    # Open a pipe to the command and read output
    my $output = `$cmd 2>&1`;
    my $exit_code = $? >> 8;

    # Check for error output
    if ($output =~ /^Error:/) {
        if ($output =~ /Error:\s+This does not seem to be a WordPress installation\./) {
            die <<"EOF";
WordPress is not installed.
Please run: bin/install-wordpress
Optionally, you can specify a version with: bin/install-wordpress --version=[version]
EOF
        } else {
            die "Failed to get WordPress version:\n$output";
        }
    }

    # If wp-cli fails for other reasons (non-zero exit code), also die
    if ($exit_code != 0) {
        die "Failed to get WordPress version using wp-cli:\n$output";
    }

    my $version = trim($output);  # Strip whitespace/newlines
    return $version;
}

# Backup the WordPress database into structure.sql, data.sql, and full.sql,
# then zip the result into var/db_backups/SITE_NAME-timestamp-version.zip
sub wordpress_database_backup {
    use File::Path qw(make_path rmtree);
    use File::Basename qw(dirname);
    use Cwd qw(abs_path);
    use POSIX qw(strftime);
    use File::Temp qw(tempdir);
    use String::Random;

    require WPControl::Config;
    WPControl::Config->import(qw(get_configuration));

    my $applicationRoot = abs_path(dirname(abs_path(__FILE__)) . '/../../../');
    my $tmpDir          = "$applicationRoot/tmp";
    my $varDir          = "$applicationRoot/var";
    my $backupDir       = "$varDir/db_backups";
    my $binDir          = "$applicationRoot/bin";
    my $wp_cli_path     = "$binDir/wp";

    my %cfg = get_configuration();
    my $db_cfg = $cfg{wordpress};

    my $dbname    = $db_cfg->{DB_NAME}     // die "Missing DB_NAME in configuration";
    my $wpVersion = get_wordpress_version();
    my $ts        = time();
    my $date      = strftime('%Y-%m-%d', localtime($ts));
    my $rand      = String::Random->new->randpattern("CCCCcccc");

    my $siteName    = $cfg{meta}{SITE_NAME} // 'wp-site';
    my $backupSlug  = "$siteName-$ts-$wpVersion";

    my $tmpBackup = "$tmpDir/$backupSlug";
    rmtree($tmpBackup) if -d $tmpBackup;
    make_path($tmpBackup) or die "Could not create temporary backup directory: $tmpBackup";

    my $sqlFile = "$tmpBackup/${dbname}-${date}-${rand}.sql";

    # Perform the export using WP-CLI
    my $cmd = "$wp_cli_path db export " . shell_quote($sqlFile);
    system($cmd) == 0 or die "❌ Failed to export database using wp-cli\n";

    die "❌ Export failed: missing expected SQL file $sqlFile\n" unless -f $sqlFile;

    my $zip_path = "$backupDir/$backupSlug.zip";
    unlink $zip_path if -e $zip_path;
    make_path($backupDir) unless -d $backupDir;

    my $zip_cmd = join(' ', 'zip', '-j', shell_quote($zip_path), shell_quote($sqlFile));
    system($zip_cmd) == 0 or die "❌ Failed to create archive: $zip_path\n";

    die "❌ Archive not created: $zip_path\n" unless -e $zip_path;

    print "\n✅ WordPress database was successfully backed up!\n";
    print "→ Archive: $zip_path\n";
    print "→ To restore: bin/db-restore --archive=$zip_path\n\n";

    rmtree($tmpBackup);
    print "🧹 Temporary folder removed: $tmpBackup\n";

    return 1;
}

sub mysql_dump {
    my (%args) = @_;

    my $host     = $args{host}     // '127.0.0.1';
    my $port     = $args{port}     // 3306;
    my $user     = $args{user}     // die "MySQL user is required";
    my $password = $args{password} // die "MySQL password is required";
    my $dbname   = $args{dbname}   // die "MySQL database name is required";
    my $mode     = $args{mode}     // 'full';  # full | structure | data
    my $output   = $args{output}   // die "Output file path is required";

    my @flags = (
        "-h", $host,
        "-P", $port,
        "-u", $user,
        "-p$password",
        "--no-tablespaces",
    );

    if ($mode eq 'structure') {
        push @flags, '--no-data';
    } elsif ($mode eq 'data') {
        push @flags, '--no-create-info';
    } elsif ($mode ne 'full') {
        die "Invalid mode: $mode. Must be one of: full, structure, data";
    }

    my $cmd = join(' ', 'mysqldump', @flags, $dbname, ">", shell_quote($output), '2>/dev/null');

    # No verbose output — silent run
    system($cmd) == 0
        or die "❌ Failed to run mysqldump for mode [$mode] to $output\n";
}

# Restores a WordPress database from a previously created archive
# Usage: wordpress_database_restore(--archive => '/path/to/archive.zip', --scope => 'structure'|'data'|'full')
sub wordpress_database_restore {
    use File::Path qw(make_path rmtree);
    use File::Basename qw(fileparse);
    use Cwd qw(abs_path);
    use Term::Menus;
    use Archive::Zip qw(:ERROR_CODES :CONSTANTS);

    require WPControl::Config;
    WPControl::Config->import(qw(get_configuration));

    my (%args) = @_;

    my $applicationRoot = abs_path(dirname(abs_path(__FILE__)) . '/../../../');
    my $binDir          = "$applicationRoot/bin";
    my $tmpDir          = "$applicationRoot/tmp";
    my $varDir          = "$applicationRoot/var";
    my $backupDir       = "$varDir/db_backups";
    my $wp_cli_path     = "$binDir/wp";

    my %cfg = get_configuration();
    my $archive = $args{archive};

    if (!$archive) {
        opendir(my $dh, $backupDir) or die "Failed to open $backupDir: $!";
        my @archives = reverse sort { (stat("$backupDir/$a"))[9] <=> (stat("$backupDir/$b"))[9] }
                       grep { /\.zip$/ && -f "$backupDir/$_" } readdir($dh);
        closedir($dh);

        @archives = @archives[0 .. 9] if @archives > 10;
        die "No backup archives found in $backupDir\n" unless @archives;

        my $banner = "  Choose a backup archive to restore:";
        my @labels = map { format_backup_label($_) } @archives;

        my $picked_label = &pick(\@labels, $banner);
        die "No archive selected.\n" unless defined $picked_label;

        my ($index) = grep { $labels[$_] eq $picked_label } 0..$#labels;
        my $picked_file = $archives[$index];

        $archive = "$backupDir/$picked_file";
    }

    die "Specified archive does not exist: $archive\n" unless -f $archive;

    my $basename = fileparse($archive, qr/\.zip$/);
    my $restoreDir = "$tmpDir/restore-$basename";
    rmtree($restoreDir) if -d $restoreDir;
    make_path($restoreDir) or die "Could not create restore directory: $restoreDir";

    my $zip = Archive::Zip->new();
    $zip->read($archive) == AZ_OK or die "Failed to read zip archive: $archive\n";

    foreach my $member ($zip->members()) {
        $zip->extractMember($member, "$restoreDir/" . $member->fileName) == AZ_OK
            or die "Failed to extract file " . $member->fileName . " from $archive\n";
    }

    my $dbname = $cfg{wordpress}->{DB_NAME} or die "Missing DB_NAME in configuration";
    my $pattern = qr{^\Q$dbname\E-\d{4}-\d{2}-\d{2}-[A-Za-z0-9]{8}\.sql$};

    my ($sql_file) = map { "$restoreDir/$_" }
                    grep { $_ =~ $pattern }
                    map  { $_->fileName }
                    $zip->members();

    die "❌ Could not locate expected SQL file matching pattern '$pattern'\n" unless $sql_file && -f $sql_file;
    die "❌ No .sql file found in archive.\n" unless defined $sql_file && -f $sql_file;

    print "\n⚠️  Restoring database from: $sql_file\n";

    my $cmd = "$wp_cli_path db import " . shell_quote($sql_file);
    system($cmd) == 0 or die "❌ Failed to restore database from $sql_file\n";

    print "\n✅ WordPress database was successfully restored from: $sql_file\n";

    rmtree($restoreDir);
    print "🧹 Temporary restore folder removed: $restoreDir\n";

    return 1;
}

# Returns a nicely formatted label for a backup archive file
sub format_backup_label {
    my ($filename) = @_;

    if ($filename =~ /^.+-(\d+)-.+\.zip$/) {
        my $timestamp = $1;
        my @t = localtime($timestamp);
        my $formatted = sprintf("%02d-%02d-%04d %02d:%02d",
            $t[4] + 1,  # month (0-based)
            $t[3],      # day
            $t[5] + 1900, # year
            $t[2],      # hour
            $t[1]       # minute
        );
        return "$filename    [ $formatted ]";
    }

    return $filename; # fallback
}

# Prompts the user to securely enter and confirm a password, with retry on mismatch
sub prompt_user_password {
    use Term::Prompt qw(prompt);
    use Term::ANSIColor qw(:constants);

    my $password  = prompt('p', 'Enter a password: ', '', '');
    print "\n";  # Add newline manually
    my $confirm   = prompt('p', 'Confirm the password: ', '', '');
    print "\n";  # Add newline manually

    if ($password eq $confirm) {
        return $password;
    }

    print BOLD RED "❌ Password and confirmation do not match.\n" . RESET;

    my $retry = prompt('y', 'Would you like to try again?', '', 'y');

    if (lc($retry) eq 'y') {
        return prompt_user_password();  # Recursive retry
    } else {
        print BOLD YELLOW "Aborted by user.\n" . RESET;
        exit 1;
    }
}

# Prints a spash screen message.
sub splash() {
  print (''."\n");
  print ('+--------------------------------------------------------------------------------------+'."\n");
  print ('| Thank you for choosing wp-control                                                    |'."\n");
  print ('+--------------------------------------------------------------------------------------+'."\n");
  print ('| Copyright (c) 2023 Jesse Greathouse (https://github.com/jesse-greathouse/wp-control) |'."\n");
  print ('+--------------------------------------------------------------------------------------+'."\n");
  print ('| wp-control is free software: you can redistribute it and/or modify it under the      |'."\n");
  print ('| terms of the Free Software Foundation, either version 3 of the License, or GNU       |'."\n");
  print ('| General Public License as published by (at your option) any later version.           |'."\n");
  print ('|                                                                                      |'."\n");
  print ('| wp-control is distributed in the hope that it will be useful, but WITHOUT ANY        |'."\n");
  print ('| WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A      |'."\n");
  print ('| PARTICULAR PURPOSE.  See the GNU General Public License for more details.            |'."\n");
  print ('|                                                                                      |'."\n");
  print ('| You should have received a copy of the GNU General Public License along with         |'."\n");
  print ('| wp-control. If not, see <http://www.gnu.org/licenses/>.                              |'."\n");
  print ('+--------------------------------------------------------------------------------------+'."\n");
  print ('| Author: Jesse Greathouse <jesse.greathouse@gmail.com>                                |'."\n");
  print ('+--------------------------------------------------------------------------------------+'."\n");
  print (''."\n");
}

1;
