#!/usr/bin/perl

package WPControl::Web;

use strict;
use File::Basename;
use Getopt::Long;
use Cwd qw(getcwd abs_path);
use Exporter 'import';
use lib(dirname(abs_path(__FILE__))  . "/../modules");
use WPControl::Config qw(get_configuration);
use WPControl::Utility qw(command_result is_pid_running splash trim);
use Term::ANSIScreen qw(cls);

our @EXPORT_OK = qw(web_start web_restart web_stop web_kill web_help web_status is_web_up);

warn $@ if $@; # handle exception

# Folder Paths
my $binDir            = abs_path(dirname(__FILE__) . '/../../');
my $applicationRoot   = abs_path(dirname($binDir));
my $optDir            = "$applicationRoot/opt";
my $etcDir            = "$applicationRoot/etc";
my $srcDir            = "$applicationRoot/src";
my $tmpDir            = "$applicationRoot/tmp";
my $varDir            = "$applicationRoot/var";
my $webDir            = "$applicationRoot/web";
my $cacheDir          = "$varDir/cache";
my $logDir            = "$varDir/log";
my $user              = $ENV{"LOGNAME"};
my $errorLog          = "$logDir/error.log";
my $supervisorConfig  = "$etcDir/supervisor/conf.d/supervisord.conf";
my $supervisorLogFile = "$logDir/supervisord.log";
my $pidFile           = "$varDir/pid/supervisord.pid";

our %service_roles = (
    cleancache => qr/^cleancache:/,
    dhp        => qr/^dhp:/,
    nginx      => qr/^nginx:/,
    php        => qr/^php:/,
);

our %status_icons = (
    cleancache => {
        'EXITED'  => "✅",
        'RUNNING' => "⚠️",
    },
    dhp => {
        'EXITED'  => "✅",
        'RUNNING' => "⚠️",
    },
    nginx => {
        'RUNNING' => "✅",
    },
    php => {
        'RUNNING' => "✅",
    },
);

# Get Configuration
my %cfg = get_configuration();

# ====================================
#    Subroutines below this point
# ====================================

# Displays help for available web actions.
sub web_help {
    print <<'EOF';
Usage: web [ACTION]

Manage the web service via the following actions:

Examples:
  web start              # Start the web service
  web restart            # Restart the web service
  web stop               # Stop the web service
  web kill               # Stop service and the supervisor daemon (for config changes)
  web status             # Show the current status of all web services
  web help               # Show this help information

 Main operation modes:
  start                  Start the web service
  restart                Restart the web service
  stop                   Gracefully stop the web service
  kill                   Stop service and supervisor daemon (for config changes)
  status                 Display current status of web-managed services
  help                   Display this help message

EOF
}

# Runs the web manager supervisor.
sub web_start {
    if ( -e $pidFile && is_pid_running($pidFile)) {
        my @cmd = ('supervisorctl', '-c', $supervisorConfig, 'start', 'all');
        system(@cmd);
        command_result($?, $!, 'Start all Web Services...', \@cmd);
    } else {
        start_daemon();
    }
}

# Restarts the web manager supervisor.
sub web_restart {
    my $output = "The Web Daemon was not found.\n";

    if ( -e $pidFile && is_pid_running($pidFile)) {
        my @cmd = ('supervisorctl', '-c', $supervisorConfig, 'restart', 'all');
        system(@cmd);

        $output = "The Web Daemon was signalled to restart all Web Services.\n";
        command_result($?, $!, 'Restart all Web Services...', \@cmd);
    }

    print $output;
}

# Stops the web manager supervisor.
sub web_stop {
    my $output = "The Web Daemon was not found.\n";

    if ( -e $pidFile && is_pid_running($pidFile)) {
        my @cmd = ('supervisorctl', '-c', $supervisorConfig, 'stop', 'all');
        system(@cmd);

        $output = "The Web Daemon was signalled to stop all Web Services.\n";
        command_result($?, $!, 'Stop all Web Services...', \@cmd);
    }

    print $output;
}

# Kills the supervisor daemon (Useful to change configuration.).
# Usually you just want to stop, start, restart.
# Killing the daemon will shut off supervisor controls.
# Only use this to change a configuration file setting.
sub web_kill {
    my $output = "The Web Daemon was not found.\n";

    if ( -e $pidFile && is_pid_running($pidFile)) {
        open my $fh, '<', $pidFile or die "Can't open $pidFile: $!";
        my $content = do { local $/; <$fh> };
        close $fh;

        my ($pid) = $content =~ /^.*?(\d+).*?$/s or die "Invalid PID format in $pidFile\n";

        # First try a graceful shutdown
        if (kill 'TERM', $pid) {
            $output = "Sent SIGTERM to process $pid.\n";
        } else {
            warn "Failed to send SIGTERM to $pid, trying SIGKILL...\n";
            if (kill 9, $pid) {
                $output = "Forcefully killed process $pid with SIGKILL.\n";
            } else {
                warn "Failed to kill process $pid.\n";
            }
        }
    }

    print $output;
}

sub is_web_up {
    my @status_lines = `supervisorctl -c $supervisorConfig status`;
    foreach my $line (@status_lines) {
        chomp $line;
        my ($name, $status, $rest) = $line =~ /^(\S+)\s+(\S+)\s+(.*)$/;
        $status = trim($status // '');

        my $matched_role;
        for my $role (keys %service_roles) {
            if ($name =~ $service_roles{$role}) {
                $matched_role = $role;
                last;
            }
        }

        return 0 unless $matched_role;
        return 0 unless exists $status_icons{$matched_role}{$status};
    }
    return 1;
}

sub web_status {
    print <<"BANNER";

=================================================================
 Web Service Status
=================================================================

BANNER

    my @status_lines = `supervisorctl -c $supervisorConfig status`;
    foreach my $line (@status_lines) {
        chomp $line;

        my ($name, $status, $rest) = $line =~ /^(\S+)\s+(\S+)\s+(.*)$/;
        $status = trim($status // '');

        my $matched_role;
        for my $role (keys %service_roles) {
            if ($name =~ $service_roles{$role}) {
                $matched_role = $role;
                last;
            }
        }

        $matched_role //= 'unknown';

        my $icon = $status_icons{$matched_role}{$status} // '❌';
        my $label = $matched_role ne 'unknown' ? "$matched_role:$name" : $name;

        printf "%s  %-12s %-8s %s\n", $icon, $matched_role, $status, $rest;
    }

    if (is_web_up()) {
        print "\n📝  Use 'bin/web restart' or 'bin/web stop' if you need to cycle the Web service.\n\n";
    } else {
        print "\n🛠️  One or more Web services are not running. Use 'bin/web start' to bring them up.\n\n";
    }
}


# Starts the supervisor daemon.
sub start_daemon {
    @ENV{qw(
      SITE_NAME DEBUG SSL PORT REDIS_HOST REDIS_DB REDIS_PORT REDIS_PASSWORD
      DIR BIN ETC OPT TMP VAR SRC WEB LOG_DIR CACHE_DIR
      DB_HOST DB_USER DB_PASSWORD DB_NAME DB_PORT
  )} = (
      $cfg{meta}{SITE_NAME},
      $cfg{wordpress}{DEBUG},
      $cfg{nginx}{IS_SSL},
      $cfg{nginx}{PORT},
      $cfg{wordpress}{REDIS_HOST},
      $cfg{wordpress}{REDIS_DB},
      $cfg{wordpress}{REDIS_PORT},
      $cfg{wordpress}{REDIS_PASSWORD},
      $applicationRoot,
      $binDir,
      $etcDir,
      $optDir,
      $tmpDir,
      $varDir,
      $srcDir,
      $webDir,
      $logDir,
      $cacheDir,
      $cfg{wordpress}{DB_HOST},
      $cfg{wordpress}{DB_USER},
      $cfg{wordpress}{DB_PASSWORD},
      $cfg{wordpress}{DB_NAME},
      $cfg{wordpress}{DB_PORT}
  );

    print "Starting Web Daemon...\n";

    system('supervisord', '-c', $supervisorConfig);

    sleep(4);
    print_output();

    if (is_web_up()) {
        my $admin_url = "$cfg{wordpress}{SITE_URL}/wp-admin";
        print <<"NOTICE";

🎉 All Web services are running normally.

🔗 You can now access the WordPress admin interface at:
    $admin_url

NOTICE
    } else {
        print <<"WARNING";

⚠️  Some web services did not start as expected.

You may wish to inspect logs or run:
    bin/web status

WARNING
    }
}

sub print_output {
    system('tail', '-n', '18', $supervisorLogFile);
}

1;
