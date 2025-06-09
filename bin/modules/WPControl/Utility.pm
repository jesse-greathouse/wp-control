#!/usr/bin/perl

package WPControl::Utility;

use strict;
use Exporter 'import';
use Errno;
use POSIX 'ceil';

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
        { pattern => 'centos',          name => 'CentOS' },
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

# Prints a spash screen message.
sub splash() {
  print (''."\n");
  print ('+--------------------------------------------------------------------------------------+'."\n");
  print ('| Thank you for choosing wp-control                                                    |'."\n");
  print ('+--------------------------------------------------------------------------------------+'."\n");
  print ('| Copyright (c) 2023 Jesse Greathouse (https://github.com/jesse-greathouse/wp-control) |'."\n");
  print ('+--------------------------------------------------------------------------------------+'."\n");
  print ('| wp-control is free software: you can redistribute it and/or modify it under the      |'."\n");
  print ('| terms of thethe Free Software Foundation, either version 3 of the License, or GNU    |'."\n");
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
