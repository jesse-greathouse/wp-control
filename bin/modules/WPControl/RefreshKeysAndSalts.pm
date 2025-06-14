#!/usr/bin/perl

package WPControl::RefreshKeysAndSalts;
use strict;
use warnings;
use File::Basename;
use File::Path qw(make_path);
use File::Temp qw(tempfile);
use File::Copy qw(move);
use Fcntl ':mode';
use Cwd qw(abs_path);
use Exporter 'import';

our @EXPORT_OK = qw(refresh_keys_and_salts);

warn $@ if $@; # handle exception

# Folder Paths
my $applicationRoot = abs_path(dirname(abs_path(__FILE__)) . '/../../../');
my $varDir          = "$applicationRoot/var";
my $keysDir         = "$varDir/keys";
my $keysAndSalts    = "$keysDir/wordpress-keys-and-salts.php";

# Refresh the WordPress Keys and Salts File
sub refresh_keys_and_salts {
    # Create keys directory if it doesn't exist
    unless (-d $keysDir) {
        make_path($keysDir, { mode => 0700 }) or die "Failed to create $keysDir: $!";
    }

    # Remove existing file if it exists
    if (-e $keysAndSalts) {
        unlink $keysAndSalts or die "Failed to remove existing $keysAndSalts: $!";
    }

    # Open file and write PHP opening tag
    open(my $fh, '>', $keysAndSalts) or die "Cannot open $keysAndSalts for writing: $!";
    print $fh "<?php\n" or die "Failed to write to $keysAndSalts: $!";
    close $fh;

    # Append content from WordPress secret key API
    my $cmd = "curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ >> '$keysAndSalts'";
    system($cmd) == 0 or die "Failed to fetch keys and salts from WordPress API";

    # Set secure permissions
    chmod 0700, $keysAndSalts or die "Failed to set permissions on $keysAndSalts: $!";
}

1;
