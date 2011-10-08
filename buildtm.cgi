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

# Used to set the maximum load that we will still respond to gitweb queries.
# If server load exceed this value then return "503 server busy" error.
# If gitweb cannot determined server load, it is taken to be 0.
# Leave it undefined (or set to 'undef') to turn off load checking.
our $maxload = 5;

our $apacheip=`/sbin/ifconfig eth0|sed -n 's/.*inet addr:\\([^ ]*\\).*/\\1/p'`;
our $browserip=$ENV{'REMOTE_ADDR'};
our $browserusr='guest';
our $thisscript=`readlink -f -n $0`;
our $thisscrihm=`dirname $thisscript`;
chomp($apacheip);
chomp($thisscrihm);

our $action;
our %actions = (
	"checkin"  	=> \&html_login,
	"loadavg"  	=> \&check_loadavg,
        "taskstat" 	=> \&manage_tasks,
        "rebuild"  	=> \&rebuild_project,
        "stopbuild"  	=> \&stopbuild_project,
        "cookies"  	=> \&cookies_test,
        "bt"       	=> \&bug_test,
        "kill"     	=> \&kill_project,
);

our %known_tasks = (
	'projexample' => {
		'title'   => 'Please give your project title',
		'script'  => '/the/abs/path/name/of/your/build/script',
                'hostip'  => '10.0.0.1',
                'rebuild' => 'off',
                'kill'    => 'off',
		},
);
require  "$thisscript.cfg.pl";

our %known_cookies = (
    'cookyspec' => {
           'domain'  => 'a partial or complete domain name for which the cookie is valid. Like .devdaily.com',
           'expires' => '(optional) +60s +20m +5h nowimmediately +5M +1y',
           'name'    => 'the name of the cookie (required)',
           'path'    => '(optional), default to / ',
           'secure'  => '(optional)',
           'value'   => 'required, can be one of $ % @ variable',
           },
);

our $results_dir;
our %input_params = ();
our ($my_url, $my_uri, $base_url, $path_info, $home_link);
our $cgi=new CGI;

# Go!
#----------------------------------------------------------------
&evaluate_uri;
&parseform;
&html_head;
&html_debug;
&dispatch;
&html_tail;
exit; 


sub cookies_test {
    print "<br>\n";
    print "Cooies test start --------------------<br>\n";

    use CGI;
    $query = new CGI;
    $cookie = $query->cookie(-name=>'MY_COOKIE',
	 -value=>'BEST_COOKIE=chocolatechip',
	 -expires=>'+4h',
	 -path=>'/');
    #print $query->header(-cookie=>$cookie);

    $theCookie = $query->cookie('MY_COOKIE');
    if ("$theCookie") {
        print "<BLOCKQUOTE>\n";
        print "if theCookie exist, will be displayed here---=== [$theCookie] ===---";
        print "</BLOCKQUOTE>\n";
    } else {
       print "Can't find my cookie!<br>\n";
    }

    print "-+-$ENV{'HTTP_COOKIE'}-+-<br>\n";
    @pairs = split(/&/, $ENV{'HTTP_COOKIE'});
    foreach $pair (@pairs){
        ($name, $value) = split(/=/, $pair);
        $value =~ tr/+/ /;
        $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $cookie{$name} = $value;
        print "Cooies $name = $value --------------------<br>\n";
    }

    print "Cooies test done --------------------<br>\n";
}
sub bug_test {
    print "Bug test start --------------------<br>\n";
    my $hip="10.16.13.195";
    my $stret=`ssh build\@$hip \"uptime\"`;
    print "uptime: <font face='courier new' color=blue><b>$stret</b></font><br>";

    my $stret=`ssh build\@$hip \"echo this is a echo with free workds as parameters\"`;
    print "echo: <font face='courier new' color=blue><b>$stret</b></font><br>";

    print "ENV{'REMOTE_ADDR'  }:  -- $ENV{'REMOTE_ADDR'  } <br> \n";
    print "ENV{'HTTP_REFERER' }:  -- $ENV{'HTTP_REFERER' } <br> \n";
    print "ENV{'HTTP_HOST'    }:  -- $ENV{'HTTP_HOST'    } <br> \n";
    print "ENV{'DOCUMENT_ROOT'}:  -- $ENV{'DOCUMENT_ROOT'} <br> \n";
    print "ENV{'REQUEST_URI'  }:  -- $ENV{'REQUEST_URI'  } <br> \n";
    print "ENV{'SERVER_NAME'  }:  -- $ENV{'SERVER_NAME'  } <br> \n";
    
    print "searched ENV[*] --------------------<br>\n";
    my $k;
    foreach $k (sort keys %ENV) {
        my $v=$ENV{$k};
        print "ENV{'$k'}:  -- $v <br> \n";
    }
    print "Bug test done --------------------<br>\n";
}
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

# Get loadavg of system, to compare against $maxload.
# Currently it requires '/proc/loadavg' present to get loadavg;
# if it is not present it returns 0, which means no load checking.
sub get_loadavg {
	if( -e '/proc/loadavg' ){
		open my $fd, '<', '/proc/loadavg'
			or return 0;
		my @load = split(/\s+/, scalar <$fd>);
		close $fd;

		# The first three columns measure CPU and IO utilization of the last one,
		# five, and 10 minute periods.  The fourth column shows the number of
		# currently running processes and the total number of processes in the m/n
		# format.  The last column displays the last process ID used.
		return $load[0] || 0;
	}
	# additional checks for load average should go here for things that don't export
	# /proc/loadavg

	return 0;
}
sub get_machine_loadavg {
    my ($usr, $hostip) = ( @_ );

    my $ret=`ssh $usr\@$hostip cat /proc/loadavg`;
    my @load = split(/\s+/, $ret);
    return $load[0] || 0;
    #print "$usr\@$hostip cat /proc/loadavg: $ret ==== $load[0] <br>\n";
}
sub check_loadavg {
    my ($usr, $hostip) = ('build','10.16.13.195');
    my $ret=`ssh $usr\@$hostip cat /proc/loadavg`;
    my @load = split(/\s+/, $ret);
    print "$usr\@$hostip cat /proc/loadavg: $ret ==== $load[0] <br>\n";

    my ($usr, $hostip) = ('build','10.16.13.196');
    my $ret=`ssh $usr\@$hostip cat /proc/loadavg`;
    my @load = split(/\s+/, $ret);
    print "$usr\@$hostip cat /proc/loadavg: $ret ==== $load[0] <br><br>\n";

    print "<b>ssh build\@10.16.13.195 \"crontab -l\"</b>\n";
    print "<pre>";
    system "ssh build\@10.16.13.195 \"crontab -l\" ";
    print "</pre>";

    print "<b>ssh build\@10.16.13.196 \"crontab -l\"</b>\n";
    print "<pre>";
    system "ssh build\@10.16.13.196 \"crontab -l\" ";
    print "</pre>";

    if (defined $maxload && get_loadavg() > $maxload) {
        die "The load average on the server is too high";
    }
}

sub check_machine_loadavg {
	if (defined $maxload && get_machine_loadavg(@_) > $maxload) {
                my ($usr, $hostip) = ( @_ );
                my $ret=`ssh $usr\@$hostip cat /proc/loadavg`;
                my @load = split(/\s+/, $ret);
                print "machine $hostip load average too high: $load[0] <br>\n";
		die "The load average on the server is too high";
	}
}

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
                #print "not defined action , default to 'taskstat'<br>\n";
		$action = 'taskstat';
	}
        #print "Dispatch action |$action|";
	if (!defined($actions{$action})) {
		die "Unknown action (debug:): $action" ;
	}
	$actions{$action}->();
}
sub print_top_results {
    our ($results_dir,$urlpre)=(@_);
    my $num_days = 9;
  
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
  
    if ($input_params{'thm'} eq '' ) {
    print "<table border=1>";
    print "<tr><th>Category</th><th>" .
       join ("</th><th>", @dates) . "</th></tr>";
    } else {
    print "<table border=0>";
    print "<tr><td class=tti >Category</td><td class=tti >" . join ("</td><td class=tti >", @dates) . "</td></tr>";
    }
   
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
               
                if ($input_params{'thm'} eq '' ) {
                $status = ($n_error) ? "${n_warning}/${n_error}" : uc($class);
                } else {
                    $status = ($n_error) ? "${n_warning}/${n_error}" : ($class);
                }
               
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

sub manage_tasks {
    my $tskid;
    foreach $tskid (sort keys %known_tasks) {
        my $scr=$known_tasks{$tskid}{'script' };
        my $liv=$known_tasks{$tskid}{'live' };
        if ( -x $scr && $liv ne 'off' ) {
            print "| <a href=#$tskid> $tskid </a>\n";
        }
    }
    print "<br>\n";
    foreach $tskid (sort keys %known_tasks) {
        my $scr=$known_tasks{$tskid}{'script' };
        my $hip=$known_tasks{$tskid}{'hostip' };
        my $tit=$known_tasks{$tskid}{'title' };
        my $reb=$known_tasks{$tskid}{'rebuild' };
        my $kil=$known_tasks{$tskid}{'kill' };
        my $liv=$known_tasks{$tskid}{'live' };
        if ( -x $scr && $liv ne 'off' ) {
            my $top= `dirname $scr`;
            chomp($top);
            my @tlock=<$top/*.lock>;
            my $nrlock=@tlock;
            my $byip=`grep CONFIG_REMOTEIP     $top/build_result/l/env.log | sed -e 's,.*=\\(.*\\),\\1,g' `;
            my $byuser=`grep CONFIG_REMOTEUSER $top/build_result/l/env.log | sed -e 's,.*=\\(.*\\),\\1,g' `;
            chomp($byip); chomp($byuser);
            if ($byip ne "" || $byuser ne "") { $byuser="runby:$byuser\@$byip"; }
            if ($input_params{'thm'} eq '' ) {
                print "<br><a name=$tskid>$tskid</a>:  <font size=+1 color=blue ><b>$tit</b></font><br>\n";
            } else {
                print "<br><a name=$tskid>$tskid</a>:  <font size=+1 color=black><b>$tit</b></font><br>\n";
            }
            print "script:$hip".'@'."$scr $byuser<br>\n";
            my $crnt=`ssh build\@$hip \"crontab -l| grep -m 1 $scr\"`;
            if ($crnt) {
                print "crontab task: <font face='courier new'><b>$crnt</b></font><br>"
            } else {
                print "no crontab item for this project<br>"
            }
            print "op : <a href=/build/link/$tskid/l/progress.log>progress</a> | ";
            print "<a href=/build/link/$tskid/l>all logs</a> |";
            print "<a href=/build/link/$tskid/l/env.log>settings</a> ";
            if ( -e "$scr.lock" || $nrlock > 0 ) {
                print ",status: <font color=red><b>running</b></font>. ";
                if ( $kil eq 'on') {
                print "<a href=$home_link?op=stopbuild&p=$tskid>stop build</a><br>";
                } else {
                print "stop build disabled";
                }
            } else {
                if ( $reb eq 'on') {
                print ",status: inactive. <a href=$home_link?op=rebuild&p=$tskid>rebuild</a><br>";
                } else {
                print ",status: inactive. rebuild disabled<br>";
                }
            }
	    unlink("/var/www/html/build/link/$tskid");
            symlink("$top/build_result", "/var/www/html/build/link/$tskid");
	    &print_top_results("$top/build_result","link/$tskid");
        }
    }
}

sub stopbuild_project {
    my $tskid=$input_params{'p'};
    my $scr=$known_tasks{$tskid}{'script' };
    my $hip=$known_tasks{$tskid}{'hostip' };
    my $tit=$known_tasks{$tskid}{'title' };
    my $reb=$known_tasks{$tskid}{'rebuild' };
    my $kil=$known_tasks{$tskid}{'kill' };

    print "<font color=blue size=+1><b>for stopping $hip:$scr</b></font><br>\n";
    if ( $kil ne 'on') {
        print "<font color=red size=+5><b>you are not in the authorized list.</b></font><br>\n";
        return 0;
    }
    if ( -x $scr ) {
        #&check_machine_loadavg('build',$hip);
        my $top= `dirname $scr`;
        chomp($top);
        my @tlock=<$top/*.lock>;
        my $nrlock=@tlock;
        if ( -e "$scr.lock" || $nrlock > 0 ) {
        } else {
            print "task not running, can not kill<br>\n";
            return 0;
        }
    } else {
            print "invalid script $scr, can not rebuild<br>\n";
            return 0;
    }
    if ( $browserip eq '10.16.2.186' ) {
    print "<font color=red size=+5><b>stoping the project's agreement</b></font><br>\n";
    print "<font color=blue >1. you really need the stop for project management reason</font><br>\n";
    print "<font color=blue >2. during job killing, a report email will send to all the involved peoples</font><br>\n";
    print "<font color=blue >3. if you insist stop the job, click the link:</font><br>\n";
    print "<a href=$home_link?op=kill&p=$tskid><font color=red >I agreed, click here to kill the job</font></a><br>\n";
    } else {
        print "<font color=red size=+5><b>you are not in the authorized list.</b></font><br>\n";
    }

    print "more info about this task:<br>\n";
    print "<pre>";
    system "ssh build\@$hip \"ps aux | grep $scr\" ";
    print "</pre>";
}

sub kill_project {
    my $tskid=$input_params{'p'};
    my $scr=$known_tasks{$tskid}{'script' };
    my $hip=$known_tasks{$tskid}{'hostip' };
    my $tit=$known_tasks{$tskid}{'title' };
    my $reb=$known_tasks{$tskid}{'rebuild' };
    my $kil=$known_tasks{$tskid}{'kill' };

    print "<font color=blue size=+1><b>for stopping $hip:$scr</b></font><br>\n";
    if ( $kil ne 'on') {
        print "<font color=red size=+5><b>you are not in the authorized list.</b></font><br>\n";
        return 0;
    }
    if ( -x $scr ) {
        #&check_machine_loadavg('build',$hip);
        my $top= `dirname $scr`;
        chomp($top);
        my @tlock=<$top/*.lock>;
        my $nrlock=@tlock;
        if ( -e "$scr.lock" || $nrlock > 0 ) {
        } else {
            print "task not running, can not kill<br>\n";
            return 0;
        }
    } else {
            print "invalid script $scr, can not rebuild<br>\n";
            return 0;
    }

    if ( $browserip eq '10.16.2.186' ) {
    print "<font color=red size=+1><b>Start killing $hip:$scr</b></font><br>\n";
    print "this may take minutes, please hold this page and<br>\n";
    print "never refresh it, click it or goes back to previous page!<br>\n";
    print "<pre>";
    system "yes \"\" | ssh build\@$hip $scr --kill-running --byip $browserip --byuser $browserusr & ";
    #print "</pre>";
    } else {
        print "<font color=red size=+5><b>you are not in the authorized list.</b></font><br>\n";
    }
}

sub rebuild_project {
    my $tskid=$input_params{'p'};
    my $scr=$known_tasks{$tskid}{'script' };
    my $hip=$known_tasks{$tskid}{'hostip' };
    my $tit=$known_tasks{$tskid}{'title' };
    my $reb=$known_tasks{$tskid}{'rebuild' };
    my $kil=$known_tasks{$tskid}{'kill' };

    print "<font color=blue size=+1><b>for rebuilding $hip:$scr</b></font><br>\n";
    if ( $reb ne 'on') {
        print "<font color=red size=+5><b>you are not in the authorized list.</b></font><br>\n";
        return 0;
    }
    if ( -x $scr ) {
        &check_machine_loadavg('build',$hip);
        my $top= `dirname $scr`;
        chomp($top);
        my @tlock=<$top/*.lock>;
        my $nrlock=@tlock;
        if ( -e "$scr.lock" || $nrlock > 0 ) {
            print "task already running or fold is locked by @tlock, can not rebuild<br>\n";
            return 0;
        }
    } else {
            print "invalid script $scr, can not rebuild<br>\n";
            return 0;
    }

    print "<font color=red size=+1><b>Start running $hip:$scr</b></font><br>\n";
    print "this may take ours, please hold this page and<br>\n";
    print "never refresh it, click it or goes back to previous page!<br>\n";
    print "<pre>";
    system "yes \"\" | ssh build\@$hip $scr --byip $browserip --byuser $browserusr & ";
    #print "</pre>";
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
<title>C2 build server runtime monitor</title>
<style type="text/css">
<!--/* <![CDATA[ */
HTML
if ($input_params{'thm'} eq '' ) {
print <<HTML;
<!--
td {text-align: center}
table {background: lightgrey}
td.category {vertical-align:top}

.pass {background: #00FF00; font-weight:bold}
.fail {background: red;  font-weight:bold}
.na   {background: grey}
.run  {background: #ffff00; font-weight:bold}
-->

HTML
} else {
print <<HTML;
<!--
td {text-align: center}
table {background: grey;  border-collapse: collapse; font-family: Arial }
td.category {vertical-align:top}
a:link {color:black}
a:visited {color:black}
a:hover {color:blue}
a:active {color:green}
.tti  {padding-left: .2em; padding-right: .2em;border: 1px #808080 solid; background: #DDDDDD; font-weight:bold}
.pass {padding-left: .2em; padding-right: .2em;border: 1px #808080 solid; background: #FFFFFF; }
.fail {padding-left: .2em; padding-right: .2em;border: 1px #808080 solid; background: #E0E0FF; font-weight:bold}
.na   {padding-left: .2em; padding-right: .2em;border: 1px #808080 solid; background: #FFFFFF}
.run  {padding-left: .2em; padding-right: .2em;border: 1px #808080 solid; background: #F0F0B0; font-weight:bold}
body  {font-family: Arial }
-->

HTML
}

print <<HTML;
/* ]]> */-->
</style>
</head>
<body>
| <a href=http://10.16.13.195/build/build.cgi>195</a>
  <a href=http://10.16.13.195/build/project.cgi?op=liclist>license</a>
| <a href=http://10.16.13.196/build/build.cgi>196</a>
  <a href=http://10.16.13.196/build/project.cgi?op=liclist>license</a>
| <a href=$home_link?op=loadavg>C2 Build server ($apacheip)</a> 
  <a href=$home_link?op=taskstat>monitor page</a> $theTime
| <a href=$home_link?op=taskstat>task manage</a>
| <a href=$home_link?thm=bonw>grey</a>
<hr>
HTML
#| <a href=$home_link?op=checkin> check in </a>
}
sub html_tail {
print "<hr> more webpage(cgi) debug info";
system "echo '<br>' Servername:; hostname";
system "echo '<br>' user:; whoami";
system "echo '<br>' script:; readlink -f $0";
print "<br>url: $my_url";
print "<br>uri: $my_uri";
print "<br>home_link: $home_link";
print "<br>path_info: $path_info";
system "echo '<br>' Current path:; pwd";
system "echo '<br>' Server info:; uname -a";
system "echo '<br>' uptime:; uptime";
print <<HTML;
<br>
C2 Build server ($apacheip) monitor page. $theTime
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
    $input_params{'p'} = $cgi->param('p');
    $input_params{'thm'} = $cgi->param('thm');
}
