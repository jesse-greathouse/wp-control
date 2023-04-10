#!/usr/bin/perl

package WPControl::Config;
use strict;
use YAML::XS qw(LoadFile DumpFile);
use POSIX qw(strftime);
use Exporter 'import';
our @EXPORT_OK = qw(get_configuration save_configuration);

my $applicationRoot = $ENV{'DIR'};
my $applicatioHiddenFolder = $applicationRoot . '/.wpc';
my $configurationFileName = '.wp-control-cfg.yml';

if (! -d $applicationRoot) {
    die "Directory: \"$applicationRoot\" doesn't exist\n $!";
}

# Create Hidden folder if it does not exist.
if (! -d $applicatioHiddenFolder) {
    mkdir($applicatioHiddenFolder) or die( "Could not create hidden folder: \"$applicatioHiddenFolder\""); 
}

1;

# ====================================
#    Subroutines below this point
# ====================================

# Returns the configuration hash.
sub get_configuration {
    my %cfg;

    # Read configuration if it exists. Create it if it does not exist
    if (-e "$applicationRoot/$configurationFileName") {
        %cfg = LoadFile("$applicationRoot/$configurationFileName");
    } else {
        print "Creating configuration file\n";
        my $libyaml = YAML::XS::LibYAML::libyaml_version();
        my $created = strftime("%F %r", localtime);
        %cfg = (
            meta => {
                created_at    => $created,
                libyaml       => $libyaml,
            }
        );
        save_configuration(%cfg);
    }

    return %cfg;
}

sub save_configuration {
    my (%cfg) = @_;
    DumpFile("$applicationRoot/$configurationFileName", %cfg);
    %cfg = LoadFile("$applicationRoot/$configurationFileName");
}
