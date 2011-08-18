#!/usr/bin/perl
use 5.008;
#use strict;
#use warnings;
use CGI qw(:standard :escapeHTML -nosticky);
use CGI::Util qw(unescape);
use CGI::Carp qw(fatalsToBrowser set_message);
use Encode;
use Fcntl ':mode';
use File::Find qw();
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
binmode STDOUT, ':utf8';

BEGIN {
	CGI->compile() if $ENV{'MOD_PERL'};
}

@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$year = 1900 + $yearOffset;
$theTime = "$hour:$minute:$second $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";

our $thisip=`/sbin/ifconfig eth0|sed -n 's/.*inet addr:\\([^ ]*\\).*/\\1/p'`;
chomp($thisip);

our $action;
our %actions = (
	"checkin"  => \&html_login,
        "taskstat" => \&output_tasks,
        "rebuild"  => \&rebuild_project,
);
our %known_tasks = (
	'proj1' => {
		'script'  => '/local/android/jazz2t-c2sdk_android/build-jazz2t-sw_media-android-devel.sh',
                'hostip'  => '10.16.13.195',
		},
	'proj2' => {
		'script'  => '/local/android/jazz2t-c2sdk_android_BR021/build-jazz2t-sw_media-android-br021.sh',
                'hostip'  => '10.16.13.195',
		},
	'proj3' => {
		'script'  => '/local/android/jazz2-c2sdk_android/build-jazz2-sw_media-android-devel.sh',
                'hostip'  => '10.16.13.195',
		},
	'proj4' => {
		'script'  => '/build/jazz2/dev-daily/build-jazz2-sdk-maintree.sh',
                'hostip'  => '10.16.13.196',
		},
	'proj5' => {
		'script'  => '/build/jazz2l/dev-daily/build-jazz2l-sdk-maintree.sh',
                'hostip'  => '10.16.13.196',
		},
	'proj6' => {
		'script'  => '/build/jazz2l/android-devel/build-jazz2l-sw_media-android-devel.sh',
                'hostip'  => '10.16.13.196',
		},
	'proj7' => {
		'script'  => '/build/jazz2t/dev-daily/build-jazz2t-sdk-maintree.sh',
                'hostip'  => '10.16.13.196',
		},
);


our $results_dir;
#our $cgi=new CGI;
our %input_params = ();
our ($my_url, $my_uri, $base_url, $path_info, $home_link);
sub evaluate_uri {
        our $cgi;

        our $my_url = $cgi->url();
        our $my_uri = $cgi->url(-absolute => 1);

        # Base URL for relative URLs in gitweb ($logo, $favicon, ...),
        # needed and used only for URLs with nonempty PATH_INFO
        our $base_url = $my_url;

        # When the script is used as DirectoryIndex, the URL does not contain the name
        # of the script file itself, and $cgi->url() fails to strip PATH_INFO, so we
        # have to do it ourselves. We make $path_info global because it's also used
        # later on.
        #
        # Another issue with the script being the DirectoryIndex is that the resulting
        # $my_url data is not the full script URL: this is good, because we want
        # generated links to keep implying the script name if it wasn't explicitly
        # indicated in the URL we're handling, but it means that $my_url cannot be used
        # as base URL.
        # Therefore, if we needed to strip PATH_INFO, then we know that we have
        # to build the base URL ourselves:
        our $path_info = $ENV{"PATH_INFO"};
        if ($path_info) {
                if ($my_url =~ s,\Q$path_info\E$,, &&
                    $my_uri =~ s,\Q$path_info\E$,, &&
                    defined $ENV{'SCRIPT_NAME'}) {
                        $base_url = $cgi->url(-base => 1) . $ENV{'SCRIPT_NAME'};
                }
        }

        # target of the home link on top of all pages
        our $home_link = $my_uri || "/";
}

our $cgi=new CGI;
&evaluate_uri;
&parseform;
&html_head;
&html_debug;
#&output_tasks;
&dispatch;
&html_tail;
exit; 

sub html_debug {
    my $count=keys %input_params;
    our $action;
    if ( $count > 0 ) {
        #my @arr = %input_params;
        #print "@arr<br>\n";
        while ( ($key, $val) = each %input_params ) {
            #print "Web data: $key => $val<br>\n";
        }
        if ($input_params{'op'} eq '' ) {
            #print "Debug: input_params{op} is |$input_params{'op'}|, no set action<br>\n";
        } else {
            #print "Debug: input_params{op} is |$input_params{'op'}|, set action<br>\n";
            $action=$input_params{'op'};
        }
    }
}

# dispatch
sub dispatch {
        our $action;
	if (!defined $action) {
                #print "not defined action , default to 'checkin'<br>\n";
		$action = 'checkin';
	}
        #print "Dispatch action |$action|";
	if (!defined($actions{$action})) {
		die "Unknown action (debug:): $action" ;
	}
	$actions{$action}->();
}
sub print_top_results {

  our ($results_dir,$urlpre)=(@_);
  #$results_dir =~ s, build_result,build_result,;
  #$results_dir='/local/android/jazz2t-c2sdk_android/build_result';
  #print "=======$results_dir========<br>\n";
  #my ($results_dir)=(@_); 
  #my $urlpre="link";
  my $num_days = 9;

  #if (defined($ENV{SDK_RESULTS_DIR})) {
  #  $results_dir = $ENV{SDK_RESULTS_DIR};
  #}else{
  #  $results_dir = "$ENV{PWD}/../build_result";
  #}

  #if (defined($ENV{SDKENV_URLPRE})) {
  #  $urlpre = $ENV{SDKENV_URLPRE};
  #}else{
  #  $urlpre = "http://127.0.0.1"
  #}

  opendir(DIR, $results_dir) or die "Couldn't open $results_dir: $!\n";

  my $log_num = grep /^(\d{2}[0,1][0-9][0-3][0-9])\.txt$/i, readdir(DIR);
  if ($log_num<10) {
    $num_days = $log_num-1;
  }

  opendir(DIR, $results_dir);
  my @dates = (sort({ $b cmp $a} grep(s/^(\d{2}[0,1][0-9][0-3][0-9])\.txt$/$1/, readdir(DIR))))[0..$num_days];

  my %results;

  for my $d (@dates) {
    open (RES, "${results_dir}/$d.txt") or die "Opening $d: $!\n";
    while (<RES>) {
      /^.*:.*:.*$/ || next;
      my ($test, $res, $logfile) = split(/:/);
      $results{$test}{$d} = [$res, $logfile];
    }
  }

  #print "Click on <b>FAIL</b> link to see log of failures<br>";

  print "<table border=1>";
  print "<tr><th>Category</th><th>" .
    join ("</th><th>", @dates) . "</th></tr>";

    my $newrow = 0;

    for my $test (keys (%results)) {
      print "<tr>" if ($newrow);

      # Make test red if the most recent test failed
      my $testclass = "na";
      if (exists($results{$test}{$dates[0]})) {
        $testclass = $results{$test}{$dates[0]}[0] == 0 ? "pass" : $results{$test}{$dates[0]}[0] == 2 ? "run" : "fail";
      }


      print "<td class=${testclass}>$test</td>";

      for my $d (@dates) {
        my $class = "na";
        my $status = "";

        if (exists($results{$test}{$d})) {
          my ($res, $log) = @{$results{$test}{$d}};
          $class = $res == 0 ? "pass" : $res == 2 ? "run" : "fail";

          my ($n_warning, $n_error) =(0,0);# check_for_results_string($log);

          $status = ($n_error) ? "${n_warning}/${n_error}" : uc($class);

          $log =~ s-$results_dir-$urlpre-;

          $status = "<a href='$log' title='gettin jiggy'>${status}</a>";
        }
        print "<td class='${class}'>${status}</td>";
      }
      print "</tr>";
      $newrow = 1;
    }
  
  print "</table>";

}

sub output_tasks {
    my $tskid;
    foreach $tskid (sort keys %known_tasks) {
        my $scr=$known_tasks{$tskid}{'script' };
        my $hip=$known_tasks{$tskid}{'hostip' };
        if ( -x $scr ) {
        print "<br>$tskid: $scr <a href=$home_link?op=rebuild&h=$hip&s=$scr>rebuild</a><br>\n";
        print "hostip: $hip <br>\n";
        my $top= `dirname $scr`;
        chomp($top);
	unlink("/var/www/html/build/link/$tskid");
        symlink("$top/build_result", "/var/www/html/build/link/$tskid");
	&print_top_results("$top/build_result","link/$tskid");
        }
    }
}

sub rebuild_project {
    my ($hostip, $script)=($input_params{'h'},$input_params{'s'});
    print "still not implement this feature for running $hostip:$script<br>\n";

    if ( $thisip eq $hostip ) {
    print "<pre>";
    print "rebuild on local machine, show root instead. local ip $thisip";
    system "ls -l /";
    print "</pre>";
    } else {
    print "<pre>";
    print "rebuild on remote machine, show cpuinfo instead, local ip $thisip";
    system "cat /proc/cpuinfo";
    print "</pre>";
    }
    
}
sub html_login {
    if ( $input_params{'username'} ne "" ) {
        print "<i>user  $input_params{'username'} logined</i><br>";
    }
print <<HTML;
<form action="$home_link?op=submit" method="POST">
<center>Add A User</center>
<center>
<table border="0" cellpadding="3" cellspacing="3">
    <tr>
        <td>Login description</td>
        <td><input type="text" size="64" name="logindesc" value="$input_params{logindesc}"></td>
    </tr>
    <tr>
        <td>Username</td>
        <td><input type="text" size="32" name="username" value="$input_params{username}"></td>
    </tr>
    <tr>
        <td>Password</td>
        <td><input type="password" size="32" name="password" value="$input_params{password}"></td>
    </tr>
    <tr>
        <td align="center" colspan="2">
        <input type="submit"  name="submit" value="Submit"></td>
    </tr>
</table>
</center>
</form>
HTML
}
sub html_head {
print "Content-type: text/html\n\n";
print <<HTML;
<html>
<head>
<title>A Simple Perl CGI</title>
<style type="text/css">
<!--/* <![CDATA[ */
<!--
td {text-align: center}
table {background: lightgrey}
td.category {vertical-align:top}

.pass {background: #00FF00; font-weight:bold}
.fail {background: red;  font-weight:bold}
.na   {background: grey}
.run  {background: #ffff00; font-weight:bold}
-->

/* ]]> */-->
</style>
</head>
<body>
C2 Build server ($thisip) monitor page. $theTime |
<a href=$home_link?op=taskstat> task status</a> |
<a href=$home_link?op=checkin> check in </a> |
<hr>
HTML
}
sub html_tail {
print "<hr> more webpage(cgi) debug info<br>";
system "echo '<br>' Servername:; hostname";
system "echo '<br>' Server info:; uname -a";
system "echo '<br>' uptime:; uptime";
system "echo '<br>' script:; readlink -f $0";
system "echo '<br>' user:; whoami";
system "echo '<br>' Current path:; pwd";
my $ls=`ls`;
print "<br>$ls<br>";
print "<br>url: $my_url";
print "<br>uri: $my_uri";
print "<br>home_link: $home_link";
print "<br>path_info: $path_info";

print <<HTML;
<p>Build server. $theTime<br>
</p>
</body>
HTML
}
sub parseform  {
    read (STDIN, $buffer, {'CONTENT_LENGTH'});
    @pairs = split(/&/, $buffer);

    foreach $pair (@pairs){
    	($name, $value) = split(/=/, $pair);
    	$value =~ tr/+/ /;
    	$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    	$input_params{$name} = $value;
    }
    #$input_params{'op'} = param('op');
    $input_params{'op'} = $cgi->param('op');
    $input_params{'h'} = $cgi->param('h');
    $input_params{'s'} = $cgi->param('s');
}