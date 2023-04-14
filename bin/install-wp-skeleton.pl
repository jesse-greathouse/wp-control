#!/usr/bin/perl

use strict;
use Getopt::Long;
use Git;
use File::Basename;
use File::Path;
use File::Find::Rule;
use File::HomeDir;
use Cwd qw(getcwd abs_path);
use Data::Dumper;
use Term::Menus;

use lib(dirname(abs_path(__FILE__))  . "/modules");
use WPControl::Config qw(get_configuration save_configuration);

my $applicationRoot = $ENV{'DIR'};
my $applicatioHiddenFolder = $applicationRoot . '/.wpc';
my $argnum;
my $skeletonRemote = undef;
my $skeletonPath = undef;
my %cfg = get_configuration();

GetOptions( "remote=s" => \$skeletonRemote,
            "path=s"   => \$skeletonPath)
or die("Error in command line arguments\n");

# Save the input to configration.
$cfg{'skeleton'}{'remote'} = $skeletonRemote;
$cfg{'skeleton'}{'path'} = $skeletonPath;
save_configuration(%cfg);

# If path is uninitialized, prompt the user for a path.
# Uses user home directory by default.
if (undef eq length $cfg{'skeleton'}{'path'}) {
  my $default_dir = get_default_directory();
  print "Use default path or change path: '(" . $default_dir . ")'\n? > ";
  chomp(my $changePathPrompt = <STDIN>);
  if ($changePathPrompt =~ /^[Y]?$/i) {   # Match Yy or blank
      $cfg{'skeleton'}{'path'} = $default_dir;
  } else {
    if (-d $changePathPrompt) {
      $cfg{'skeleton'}{'path'} = $changePathPrompt;
      save_configuration(%cfg);
    } else {
      die ( "Illegal path choice: (input: " . $changePathPrompt . ")\n");
    }
  }
}

# If Remote is uninitialized, prompt the user for a remote.
if (undef eq length $cfg{'skeleton'}{'remote'}) {
  print "Link the remote code repository: \n? > ";
  chomp($cfg{'skeleton'}{'remote'} = <STDIN>);
  my $repo_name = get_repo_name($cfg{'skeleton'}{'remote'});
  $cfg{'skeleton'}{'path'} = $cfg{'skeleton'}{'path'} . '/' . $repo_name;
  if (-d $cfg{'skeleton'}{'path'}) {
    my $isValidSkeleton = validate_skeleton_repository($cfg{'skeleton'}{'path'});
    if (!$isValidSkeleton) {
      die "Project at: \"" . $cfg{'skeleton'}{'path'} . "\" is not a valid project format.\n";
    } else {
      save_configuration(%cfg);
    }
  }
}

# Check if the repository needs to be updated.
if (-d $cfg{'skeleton'}{'path'} ) {
  my $repo = Git->repository(Directory => $cfg{'skeleton'}{'path'});
  my @status = $repo->command('fetch', '--dry-run');
  print Dumper(@status);
} else {
  print "downloading $cfg{'skeleton'}{'remote'} from remote\n";
  clone_skeleton_repository($cfg{'skeleton'}{'remote'}, $cfg{'skeleton'}{'path'});
}

# ====================================
#    Subroutines below this point
# ====================================

# Trim the whitespace from a string.
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

sub clone_skeleton_repository() {
  my ($remote, $skeletonPath) = @_;
  my @clone = Git::command('clone', $remote, $skeletonPath);
}

# Check the clone of a repository to make sure it's an actual skeleton.
# Returns boolean
sub validate_skeleton_repository {
  my ($skeletonPath) = @_;
  my %hasDirectories;
  my @essentialDirectories = (
    'client-mu-plugins',
    'custom-config',
    'images',
    'languages',
    'plugins',
    'themes',
  );

  # Get the root directories in the skeleton directory
  my $rule =  File::Find::Rule->new
    ->maxdepth(1)
    ->not(File::Find::Rule->new->name( qr/\.git$/ ));
  my @subdirs = $rule->directory->in($skeletonPath);

  # Put folder names into the hash: hasDirectories
  foreach (@subdirs) {
    my @spl = split('/', $_);
    $hasDirectories{@spl[-1]} = 1;
  }

  # Verify each essential directory exists in hasDirectories
  foreach (@essentialDirectories) {
    if (!exists($hasDirectories{$_})) {
      print "Directory: \"$_\" not found.\n";
      return 0;
    }
  }

  return 1;
}

# Generate the default directory for repositories.
# Returns String
sub get_default_directory {
  my ($repo_name) = @_;
  my $default_directory;
  my $dir = File::HomeDir->my_home;

  if (-e $dir) {
      $default_directory = $dir;
  } elsif (-e $applicationRoot) {
      $default_directory = $applicatioHiddenFolder;
  }

  if ('' ne $repo_name) {
    $default_directory = $default_directory . '/' . $repo_name
  }

  return $default_directory;
}

# Return a repo name from the input of a remote url
# Returns string
sub get_repo_name {
  my ($remote) = @_;
  my @spl = split('/', $remote);
  my $name  = @spl[-1];
  my @spltoo = split('.git', $name);
  $name = @spltoo[0];
  return $name;
}
