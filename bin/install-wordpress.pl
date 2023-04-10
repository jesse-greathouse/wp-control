#!/usr/bin/perl

use strict;
use Getopt::Long;
use JSON;
use File::Path;
use Cwd qw(getcwd);
use LWP::UserAgent ();
use LWP::Simple;
use Term::Menus;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

my $opt = $ENV{'OPT'};
my $web = $ENV{'WEB'};
my $argnum;
my @versions;
my @versionData;
my $latestVersion;
my $versionEndpoint;
my $selectedVersion;
my $requestedVersion = undef;
my $versionCheckUri = "https://api.wordpress.org/core/version-check/1.7/";
my %versionDownloadTable;

GetOptions("version=s" => \$requestedVersion) or die("Error in command line arguments\n");

# Call API for version data.
@versionData = get_version_data();

# Parse the data and assign the latest version and versions list.
for my $i (0 .. $#versionData)
{
  if ($i == 0) {
    $latestVersion = $versionData[$i]->{'version'};
  } else {
    push(@versions, $versionData[$i]->{'version'});
    $versionDownloadTable{$versionData[$i]->{'version'}} = $versionData[$i]->{'download'};
  }
}

# Validate the requested version.
# Prompt the user for a version if none was defined.
if ($requestedVersion ne undef) {
  validate_requested_version($requestedVersion, @versions);
  $selectedVersion = $requestedVersion;
  print "Requested Version: $selectedVersion \n";
} else {
  $selectedVersion = &pick(\@versions,"  Choose your WordPress Version:");
  print "Selected Version: $selectedVersion \n";
}

download_package($versionDownloadTable{$selectedVersion}, $opt);

link_package($opt, $web);

# ====================================
#    Subroutines below this point
# ====================================

# Trim the whitespace from a string.
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

# Returns API data as JSON.
sub get_version_data {
  my $ua = LWP::UserAgent->new(timeout => 10);
  my $response = $ua->get($versionCheckUri);

  if ($response->is_success) {
      my $decoded = JSON->new->utf8->decode($response->decoded_content);
      return @{$decoded->{'offers'}};
  } else {
      die $response->status_line;
  }
}

# Validate a requested version.
sub validate_requested_version {
  my ($requestedVersion, @versions) = @_;
  my %params = map { $_ => 1 } @versions;

  if(!exists($params{$requestedVersion})) {
    die "Requested version: $requestedVersion is not supported.";
  }
}

# Download the package
sub download_package {
  my ($url, $dir) = @_;
  clean_wordpress_archive($dir);

  my @spl = split("/", $url);
  my $fileName = $spl[@spl - 1];
  my $file = "$dir/$fileName";

  getstore($url, $file);

  extract_package($file, $dir);
}

sub extract_package {
  my ($file, $dir) = @_;
  my $wordpressDir = "$dir/wordpress";

  # Read the zip file
  my $zip = Archive::Zip->new();
  unless ( $zip->read( $file ) == AZ_OK ) {
    die 'read error';
  }

  my $cwd = getcwd();

  if (-d $wordpressDir) {
    rmtree($wordpressDir) or die "Couldn't remove $wordpressDir directory, $!";
  }

  mkdir($wordpressDir) or die "Couldn't create $wordpressDir directory, $!";

  chdir($wordpressDir) or die "Couldn't go inside $dir directory, $!";

  $zip->extractTree('wordpress');

  chdir($cwd) or die "Couldn't go inside $cwd directory, $!";
}

sub link_package {
  my ($dir, $webDir) = @_;
  my $wordpressDir = "$dir/wordpress";

  # Symlink the essential WordPress Directories and Files
  opendir(DH, $wordpressDir);
  my @files = readdir(DH);
  closedir(DH);

  foreach my $file (@files)
  {
    # skip unwanted files
    next if($file =~ /^\.$/);
    next if($file =~ /^\.\.$/);
    next if($file eq 'wp-content');
    next if($file eq 'readme.html');
    next if($file eq 'wp-config-sample.php');
    next if($file eq 'license.txt');

    # unlink existing symlinks
    if ( -l "$webDir/$file" ) {
      unlink "$webDir/$file"
          or warn "Failed to remove symlink $webDir/$file: $!\n";
    }

    symlink("$wordpressDir/$file", "$webDir/$file") or warn "Failed to create symlink $webDir/$file: $!\n";
  }

}

# Clean WordPress Downloads
sub clean_wordpress_archive {
  my ($dir) = @_;
  my $dh;

  opendir($dh, $dir) || die "can't opendir $dir: $!";
  my @archives = grep { /^(wordpress.*\.zip)$/ && -f "$dir/$_" } readdir($dh);
  closedir $dh;

  foreach my $file (@archives) {
    if (-e "$dir/$file") {
        unlink("$dir/$file");
    }
  }
}
