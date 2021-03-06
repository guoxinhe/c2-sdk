#!/usr/bin/perl

use CGI::Cookie;

our $home_link=$ENV{'SCRIPT_NAME'};
our $bash_home='/var/www';
our $thisscript=`readlink -f -n $0`;
our $maxload = 5;
our $browserip=$ENV{'REMOTE_ADDR'};
our %input_params = (
    'msid'           => 'none'    , #should get from cookie
    'user'           => 'guest'   , #should get from cookie
    'pswd'           => 'none'    , #should get from cookie
    'op'             => 'default' ,
    'debug'          => 'off'     ,
    'webtitle'       => 'C2 Internal',
);
our %mission_params = (
    'msid'           => 'none'    ,
    'user'           => 'guest'   ,
    'pswd'           => 'none'    ,
    'result'         => ''        ,
);
our %known_cookies = ( #cookies that must saved in client side. readonly variable
    #'expires' => '(optional) +60s +20m +5h nowimmediately +5M +1y',
    'msid' => {'value'=>'none'   ,'domain'=>'.build','expires'=>'+1y','path'=>'/','secure'=> 0,},
    'user' => {'value'=>'guest'  ,'domain'=>'.build','expires'=>'+1y','path'=>'/','secure'=> 0,},
    'pswd' => {'value'=>'none'   ,'domain'=>'.build','expires'=>'+1y','path'=>'/','secure'=> 0,},
);
our %actions = (
    'loginpage'      => \&func_loginpage,
    'myprofile'      => \&func_myprofile,
    'login'  	     => \&func_login,
    'logout'  	     => \&func_logout,
    'default'        => \&func_default,
);
our %menu_links = (
    '1  Home'        =>  "$home_link",
    '2  index'       =>  "$home_link?idx=1&thm=1",
    '3  qatest'      =>  "$home_link?op=qatest",
    '4  fstest'      =>  "$home_link?op=fstest&thm=1",
    '5  ltptest'     =>  "$home_link?op=ltptest&thm=1",
    '99 help'        =>  "$home_link?op=help",
);
our %friendly_links = (
    "1  build195"    => 'http://10.16.13.195/build/build.cgi',
    "2  build196"    => 'http://10.16.13.196/build/build.cgi',
    '3  license'     => 'http://10.16.13.195/build/project.cgi?op=liclist',
    '4  qareport'    => 'http://10.16.6.204/qa/index.cgi?idx=1',
    '5  fsreport'    => 'http://10.16.6.204/qa/index.cgi?op=fstest&thm=1',
    '6  ltpreport'   => 'http://10.16.6.204/qa/index.cgi?op=ltptest&thm=1',
);
our %system_command = (
    'Servername'     => 'hostname',
    'script'         => "readlink -f $0",
    'Current_path'   => 'pwd',
    'Server_info'    => 'uname -a',
    'uptime'         => 'uptime',
    'user'           => 'whoami',
    'home'           => 'pushd ~ >/dev/null; pwd; popd >/dev/null',
);
our %cookies = fetch CGI::Cookie();
if ( %cookies == 0 ) {
    $mission_params{'first'} = 'yes';
}
foreach $c (keys %cookies) {
        $v = $cookies{$c} -> value();
        $input_params{$c}=$v;
}
foreach $c (keys %known_cookies) {
    my $value  =$known_cookies{$c}{'value'  };
    my $expires=$known_cookies{$c}{'expires'};
    unless (grep (/^$c$/,keys %cookies)) {
        sendcookie($c,$value,$expires);
    }
}
if ( $ENV{'REQUEST_METHOD'} eq 'GET' ) {
    $input_params{'method'} = 'GET';
    #for 'get' method:
    if ( $ENV{'QUERY_STRING'} ne '' ) {
        my $buffer=$ENV{'QUERY_STRING'};
        $input_params{'buffer'} = $buffer;
        @pairs = split(/&/, $buffer);
        foreach $pair (@pairs){
            ($name, $value) = split(/=/, $pair);
            $value =~ tr/+/ /;
            $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
            $input_params{$name} = $value;
        }
    }
} else {
    $input_params{'method'} = 'POST';
    #for 'post' form:
    my $buffer;
    read (STDIN, $buffer, {'CONTENT_LENGTH'});
    $input_params{'buffer'} = $buffer;
    @pairs = split(/&/, $buffer);
    foreach $pair (@pairs){
        ($name, $value) = split(/=/, $pair);
        $value =~ tr/+/ /;
        $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $input_params{$name} = $value;
    }
}
# pre-process goes here
#----------------------------------------------------------------------------
if ( $input_params{'op'} eq 'login' ) {
    my $check_result='pass';

    #verify login information
    if ( $input_params{'username'} eq 'guest' ||
         $input_params{'username'} eq 'root'  ||
         $input_params{'username'} eq ''      ){
         $check_result='fail';
         $mission_params{'result'}='bad user name';
    }
    if ( $input_params{'password'} eq 'none'  ||
         $input_params{'password'} eq ''      ){
         $check_result='fail';
         $mission_params{'result'}='bad password';
    }
    if ( $input_params{'password'} ne '123456'    &&
         $input_params{'password'} ne '525race'   &&
         $input_params{'password'} ne 'bugfix'    ){
         $check_result='fail';
         $mission_params{'result'}='bad password';
    }
    my $i=system ("test -d /home/$input_params{'username'}");
    if ( $i != 0 ) {
        $check_result='fail';
        $mission_params{'result'}='bad user name';
    }

    if ( $check_result eq 'pass' ) {
        $mission_params{'msid'} = `date +%s`;
        chomp($mission_params{'msid'});
        $mission_params{'user'} = $input_params{'username'};
        $mission_params{'pswd'} = $input_params{'password'};

        foreach $c (keys %known_cookies) {
            my $value  =$mission_params{$c};
            my $expires=$known_cookies{$c}{'expires'};
            sendcookie($c,$value,$expires);
        }

        #save mission info to server
        system("mkdir -p $bash_home/.ssh/.users/$mission_params{'user'}");
        system("echo $mission_params{'msid'} >$bash_home/.ssh/.users/$mission_params{'user'}/msid");
    }
}
if ( $input_params{'op'} ne 'logout' ) {
    if ($mission_params{'msid'} eq $known_cookies{'msid'}{'value'  } ||
        $mission_params{'user'} eq $known_cookies{'user'}{'value'  } ||
        $mission_params{'pswd'} eq $known_cookies{'pswd'}{'value'  } ){

        my $msid='none';
        #verify login information
        if ( $input_params{'user'} ne 'guest' && $input_params{'pswd'} ne 'none' ) {
            #load user/password's msid from server
            $msid=`cat $bash_home/.ssh/.users/$input_params{'user'}/msid`;
            chomp($msid);
        }

        if ( $msid eq $input_params{'msid'} ) {
            # I am a login user.
            $mission_params{'msid'} = $input_params{'msid'};
            $mission_params{'user'} = $input_params{'user'};
            $mission_params{'pswd'} = $input_params{'pswd'};
        }
    }
}
if ( $input_params{'op'} eq 'logout' ) {
        $input_params{'msid'} = $known_cookies{'msid'}{'value'  };
        $input_params{'user'} = $known_cookies{'user'}{'value'  };
        $input_params{'pswd'} = $known_cookies{'pswd'}{'value'  };

        foreach $c (keys %known_cookies) {
            my $value  =$known_cookies{$c}{'value'  };
            my $expires=$known_cookies{$c}{'expires'};
            sendcookie($c,$value,$expires);
        }

        #save mission info to server
        $mission_params{'msid'} = $known_cookies{'msid'}{'value'  };
        $mission_params{'user'} = $known_cookies{'user'}{'value'  };
        $mission_params{'pswd'} = $known_cookies{'pswd'}{'value'  };
}

$input_params{'webtitle'} .= " build result, op: ".$input_params{'op'};
use CGI qw(:standard :escapeHTML -nosticky);
use CGI::Util qw(unescape);
use CGI::Carp qw(fatalsToBrowser set_message);
use Encode;
use Fcntl ':mode';
use File::Find qw();
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
binmode STDOUT, ':utf8';
our %known_tasks = (
	'projexample' => {
		'title'   => 'Please give your project title',
		},
);

if      ( -e "/etc/qa/qareport.cfg.pl") {
    require  "/etc/qa/qareport.cfg.pl";
} elsif ( -e "$ENV{'SCRIPT_FILENAME'}.cfg.pl") {
    require  "$ENV{'SCRIPT_FILENAME'}.cfg.pl"
} elsif ( -e "$thisscript.cfg.pl") {
    require  "$thisscript.cfg.pl";
}
if ( $input_params{'op'} eq 'qatest' ) {
    if      ( -e "/etc/qa/qareport.cfg.pl") {
        require  "/etc/qa/qareport.cfg.pl";
    }
}
# Go!
#----------------------------------------------------------------------------
customer_register();

html_head();

dispatch();

html_tail();

#############################################################
sub sendcookie {
    my ($name,$value,$life) = @_;
    my $c;
    if ($life) {
        $c = new CGI::Cookie(-name => $name,
                    -expires => $life,
                    -path => "/",
                    -value => $value);
    } else {
        $c = new CGI::Cookie(-name => $name,
                    -path => "/",
                    -value => $value);
    }
    print "Set-Cookie: ",$c->as_string,"\n";
}
# dispatch
sub dispatch {
	if (!defined $input_params{'op'}) {
		$input_params{'op'} = 'default';
	}
        my $op=$input_params{'op'};
	if (!defined($actions{$op})) {
            print "<font color=red size=+5>die: Unknown op (debug:): $op </font>" ;
	} else {
	    $actions{$op}->();
        }
}
sub userlevel {
    $mylevel=0;
    if ($mission_params{'msid'} ne $known_cookies{'msid'}{'value'  } &&
        $mission_params{'user'} ne $known_cookies{'user'}{'value'  } &&
        $mission_params{'pswd'} ne $known_cookies{'pswd'}{'value'  } ){
        $mylevel +=1;  #at least a logined user.
        if ($mission_params{'user'} eq 'hguo')      { $mylevel +=10; }
        if ($mission_params{'pswd'} eq 'bugfix')    { $mylevel +=10; }
        elsif ($mission_params{'pswd'} eq '525race') { $mylevel +=5; }
    }
    if ( $browserip eq '10.16.2.186' || $browserip eq '10.16.2.103' ) {
        $mylevel +=10;  #herman's ip
    }
    return $mylevel;
}
sub html_login {
    foreach my $mthd ('POST','GET') {
        print <<HTML;
<center><form action="$home_link?op=login" method="$mthd">
Please login(method: $mthd)
<table border="0" cellpadding="3" cellspacing="3">
    <tr><td>Username</td><td><input type="text"     size="32" name="username" value="$input_params{username}"></td></tr>
    <tr><td>Password</td><td><input type="password" size="32" name="password" value="$input_params{password}"></td></tr>
    <tr><td align="center" colspan="2"><input type="submit"   name="op" value="login"></td></tr>
</table></form></center>
HTML
    }
}
sub html_head {
    my $cellbordercss='';
    my $tablecss='background: lightgrey;  font-family: Arial';
    my ($cpass, $cfail, $cna, $cratio, $crun) = ('#00FF00','#FF0000','#DDDDDD','#00FFFF','#FFFF00');
    my ($bpass, $bfail, $bna, $bratio, $brun) = ('bold','bold','bold','bold','bold');
    my $anchorcss="";

    if (defined $input_params{'thm'}) {
        if ($input_params{'thm'} ne '') {
            ($cpass, $cfail, $cna, $cratio, $crun) = ('#FFFFFF','#FFCCCC','#FFFFFF','#B0FFFF','#FFFFB0');
            $tablecss='background: lightgrey;  border-collapse: collapse; font-family: Arial';
            $cellbordercss='padding-left: .2em; padding-right: .2em;border: 1px #808080 solid;';
            ($bpass, $bfail, $bna, $bratio, $brun) = ('','bold','','','bold');
            $anchorcss="a:link{color:black} a:visited{color:black} a:hover{color:blue} a:active{color:green} ";
        }
    }
    print "Content-type: text/html\n\n";
    print <<HTML;
<html>
<head>
<title>$input_params{webtitle}</title>
<style type="text/css">
<!--/* <![CDATA[ */
<!--
    body  {font-family: Arial }
    $anchorcss
    td {text-align: center}
    table {$tablecss}
    td.category {vertical-align:top}

    .ntfs {$cellbordercss background: #FFFF80 ; }
    .ext2 {$cellbordercss background: #FF80FF ; }
    .ext3 {$cellbordercss background: #FFC0FF ; }
    .fat32{$cellbordercss background: #FFFFA0 ; }
    .yaffs{$cellbordercss background: #FFE0C0 ; }

    .ntfsb {$cellbordercss background: #CFFF80 ; }
    .ext2b {$cellbordercss background: #CF80FF ; }
    .ext3b {$cellbordercss background: #CFC0FF ; }
    .fat32b{$cellbordercss background: #CFFFA0 ; }
    .yaffsb{$cellbordercss background: #CFE0C0 ; }

    .ntfsa {$cellbordercss background: #DFFF80 ; }
    .ext2a {$cellbordercss background: #DF80FF ; }
    .ext3a {$cellbordercss background: #DFC0FF ; }
    .fat32a{$cellbordercss background: #DFFFA0 ; }
    .yaffsa{$cellbordercss background: #DFE0C0 ; }

    .ntfsk {$cellbordercss background: #EFFF80 ; }
    .ext2k {$cellbordercss background: #EF80FF ; }
    .ext3k {$cellbordercss background: #EFC0FF ; }
    .fat32k{$cellbordercss background: #EFFFA0 ; }
    .yaffsa{$cellbordercss background: #EFE0C0 ; }

    .pass {$cellbordercss background: $cpass ; font-weight:$bpass }
    .fail {$cellbordercss background: $cfail ; font-weight:$bfail }
    .na   {$cellbordercss background: $cna   ; font-weight:$bna   }
    .ratio{$cellbordercss background: $cratio; font-weight:$bratio}
    .run  {$cellbordercss background: $crun  ; font-weight:$brun  }
-->
/* ]]> */-->
</style>

<script type="text/javascript">
    function openShutManager(oSourceObj,oTargetObj,shutAble,oOpenTip,oShutTip){
        var sourceObj = typeof oSourceObj == "string" ? document.getElementById(oSourceObj) : oSourceObj;
        var targetObj = typeof oTargetObj == "string" ? document.getElementById(oTargetObj) : oTargetObj;
        var openTip = oOpenTip || "";
        var shutTip = oShutTip || "";
        if(targetObj.style.display!="none"){
           if(shutAble) return;
           targetObj.style.display="none";
           if(openTip  &&  shutTip){
            sourceObj.innerHTML = shutTip;
           }
        } else {
           targetObj.style.display="block";
           if(openTip  &&  shutTip){
            sourceObj.innerHTML = openTip;
           }
        }
    }
    function aSheetManager(srcObj,gName,onID) {
        var i;
        var targetObj=999999;
        var name=gName +"_"+onID;
        targetObj=document.getElementById(name);
        if(targetObj || onID==0) {
            for (i=0;i<256;i++) {
                name=gName +"_"+i;
                var obj=document.getElementById(name);
                if(obj) {
                    obj.style.display="none";
                }
            }
            if(targetObj) targetObj.style.display="block";
        }
    }
</script>
</head>
<body>
HTML
    #list the top level menu
    foreach $i (sort keys %menu_links) {
        my $v=$menu_links{$i};
        $i =~ s/^\S* +//;
        print "| &nbsp;<a href=$v>$i</a>&nbsp; \n"
    }

    if ( $ENV{'SERVER_ADDR'} ne '10.16.6.204' ) { #shit, that slim guy do not like this.
        if ( $mission_params{'user'} eq 'guest' ) {
            print "| <a href=$home_link?op=loginpage>Login</a> ";
        } else {
            print "| <a href=$home_link?op=logout>Logout</a> ";
            print " <a href=$home_link?op=myprofile>$mission_params{'user'}</a> ";
        }
    }
    print "<br>\n";
    print "Website links: \n";
    foreach $i (sort keys %friendly_links) {
        my $v=$friendly_links{$i};
        $i =~ s/^\S* +//;
        print "| &nbsp;<a href=$v>$i</a>&nbsp; \n";
    }

    print "<hr>";
}

sub html_tail {
    my $i;
    print "<hr>";
    print "Website links: \n";
    foreach $i (sort keys %friendly_links) {
        my $v=$friendly_links{$i};
        $i =~ s/^\S* +//;
        print "| &nbsp;<a href=$v>$i</a>&nbsp; \n";
    }
    print "<br>\n";
    print "More webpage(cgi) debug info";
    print " <a href='###' onclick=\"openShutManager(this,'moretext',false,'hide','show')\">show</a>";
    print "<div id='moretext' style='background:#CCFFCC; display:none'>";

    print "Input parameters list:<table border=1><tr><td>Name</td><td>Value</td></tr>";
    foreach $i (sort keys %input_params) {
        my $v=$input_params{$i};
        print "<tr><td>$i</td><td>$v &nbsp;</td></tr>\n";
    }
    print "</table>";

    print "Mission parameters list:<table border=1><tr><td>Name</td><td>Value</td></tr>";
    foreach $i (sort keys %mission_params) {
        my $v=$mission_params{$i};
        print "<tr><td>$i</td><td>$v &nbsp;</td></tr>\n";
    }
    print "</table>";

    print "Perl's ENV list:<table border=1><tr><td>Name</td><td>Value</td></tr>";
    foreach $i (sort keys %ENV) {
        print "<tr><td>$i</td><td>$ENV{$i} &nbsp;</td></tr>\n";
    }
    print "</table>";

    print "System info list:<table border=1><tr><td>Name</td><td>Value</td></tr>";
    foreach $i (sort keys %system_command) {
        my $v=$system_command{$i};
        print "<tr><td>$i</td><td>";
        system ( $v );
        print " &nbsp;</td></tr>\n";
    }
    print "</table>";
    print "</div>";
    print "<br>Copyright, all rights reserved.</body></html>";
}
sub func_loginpage {
    html_login();
}
sub func_login {
    if ($mission_params{'msid'} eq $known_cookies{'msid'}{'value'  } ||
        $mission_params{'user'} eq $known_cookies{'user'}{'value'  } ){
        print "login fail<br>\n";
    } else {
        print "login ok<br>\n";
    }
}
sub func_logout {
    print "logout ok<br>\n";
}
sub func_myprofile {
    $mylevel=userlevel();
    print "Welcome $mission_params{'user'}, your user level is: $mylevel<br><pre>\n";

    system ("id $mission_params{'user'}");
    system ("uname -a");
    print "</pre>\n";
    my @pagename=('Hide all','a','b','c','d','e','f','g','h');
    foreach $i (0..8) {
        print " | <a href=### onclick=\"aSheetManager(this,'mygroup',$i)\">Page $i: $pagename[$i]</a>"
    }
    my @folder=('','/boot','/','/etc','/proc','/var','/dev','/usr','/home');
    foreach $i (1..8) {
        if ($i == 1) {
        print "<div id='mygroup_$i' style='background:#CCFFCC; display:block'>";
        } else {
        print "<div id='mygroup_$i' style='background:#CCFFCC; display:none'>";
        };
        print "this is seet $i<pre>";
        my $fd=$folder[$i];
        system ("echo ls -l $fd");
        system ("ls -l $fd");
        print "</pre>this is seet $i<br>";
        print "</div>";
    }

}
sub func_default {
    print "the op is $input_params{'op'}<br>\n";
}

# Your extension code goes here:)
#----------------------------------------------------------------------------
sub customer_register {
    #register your operations here.
    if ( $ENV{'SERVER_ADDR'} ne '10.16.6.204' ) { #shit, that slim guy do not like this.
        $actions{"default"  }=\&manage_tasks;
    } else {
        $actions{"default"  }=\&show_qatest;
    }
    $actions{"help"     }=\&serverside_help;
    $actions{"rebuild"  }=\&rebuild_project;
    $actions{"stopbuild"}=\&stopbuild_project;
    $actions{"kill"     }=\&kill_project;
    $actions{"qatest"   }=\&show_qatest;
    $actions{"fstest"   }=\&show_fstest;
    $actions{"ltptest"  }=\&show_ltptest;
}

sub serverside_help {
my $kwd='build_result';
print <<HTML;
<pre>
stand log format:
1. Folder name is '$kwd':
    /your/local/path/$kwd

2. log file is found direct in folder: /your/local/path/$kwd
   log file name is: yymmdd.txt, like
        110901.txt  110902.txt

3. log line format:
   Category:[cate level 2:[cate level 3:]]res:/abs/path/$kwd/yoursubdir/xxx.log\
   cate level 2 is optional.
   cate level 3 is optional.
   res type 1, number: 0: pass, 1: fail, 2: running, other number: fail
   res type 2, ratio : 22/30

   Basic   format: tv:0:/qatest/tv/$kwd/balabala/tv.log
   2 Level format: tv:turner:0:/qatest/tv/$kwd/balabala/tvturner.log
   3 Level format: tv:turner:save:0:/qatest/tv/$kwd/balabala/tvturnersave.log
</pre>
HTML
}

sub parse_files_by_date {
    my ($num_days, $results_dir, $filter, $urlfilter, $urlpre, $enable_index)=(@_);
    my $fields = 0;

    if ( ! opendir(DIR, $results_dir) ) {
        print "Die: Couldn't open $results_dir: $!<br>\n";
        return 0;
    }

    my $log_num = grep /^$filter$/i, readdir(DIR);
    if ( $log_num < $num_days ) {
        $num_days = $log_num;
    }
    close(DIR);

    opendir(DIR, $results_dir);
    my @dates = (sort({ $b cmp $a} grep(s/^$filter$/$1/, readdir(DIR))))[0..($num_days-1)];
    close(DIR);

    my %results;
    for my $d (@dates) {
        if ( ! open (RES, "$results_dir/$d.txt") ) {
           print "Die: Opening $results_dir/$d.txt: $!\n";
        }

        while (<RES>) {
            if ( $_ =~ /^.*:.*:.*:.*:.*$/ ) {
                my ($fcategory, $fsubitem, $fsubsec, $res, $logfile) = split(/:/);
                $results{$fcategory}{$fsubitem}{$fsubsec}{$d} = [$res, $logfile, $fcategory, $fsubitem,$fsubsec];
		if ($fields < 5) { $fields = 5; }
            } elsif ( $_ =~ /^.*:.*:.*:.*$/ ) {
                my ($fcategory, $fsubitem, $res, $logfile) = split(/:/);
		my $fsubsec='x';
                $results{$fcategory}{$fsubitem}{$fsubsec}{$d} = [$res, $logfile, $fcategory, $fsubitem,$fsubsec];
		if ($fields < 4) { $fields = 4; }
            } elsif ( $_ =~ /^.*:.*:.*$/ ) {
                my ($fcategory, $res, $logfile) = split(/:/);
                my $fsubitem='x';
		my $fsubsec='x';
                $results{$fcategory}{$fsubitem}{$fsubsec}{$d} = [$res, $logfile, $fcategory, $fsubitem,$fsubsec];
		if ($fields < 3) { $fields = 3; }
            } else {
                next;
            }
        }
    }

    print "<table border=1>";
    print "</tr>";
    if ($enable_index) { print "<th>Index</th>" ;}
    print "<th>Category</th>" ;
    if ($fields > 3) { print "<th>subitem</th>" ;}
    if ($fields > 4) { print "<th>subsec </th>" ;}
    print "<th>" . join ("</th><th>", @dates) . "</th>";
    print "</tr>";

    my $line_index=0;
    for my $category (sort keys  (%results)) {
    for my $subitem  (sort keys %{$results{$category}}) {
    for my $subsec   (sort keys %{$results{$category}{$subitem}}) {
        $line_index += 1;
        print "<tr>";
        my $class = "na";
        if (exists($results{$category}{$subitem}{$subsec}{$dates[0]})) {
            my ($res, $logfile, $fcategory, $fsubitem, $fsubsec) = @{$results{$category}{$subitem}{$subsec}{$dates[0]}};
            my ($nrfail, $nrall) = split(/\//,$res);
            if ( $nrall eq '' ) {
                $class = $res == 0 ? "pass" : $res == 2 ? "run" : "fail";
            } else {
                $class = "ratio";
            }
        }
        if ($enable_index) { print  "<td>$line_index</td>"; }
        print                    "<td class='$class'>$category</td>";
        if ($fields > 3) { print "<td class='$class'>$subitem </td>";}
        if ($fields > 4) { print "<td class='$class'>$subsec  </td>";}

        for my $d (@dates) {
            my $class = "na";
            my $status = "&nbsp;";
            if (exists($results{$category}{$subitem}{$subsec}{$d})) {
                my ($res, $logfile, $fcategory, $fsubitem, $fsubsec) = @{$results{$category}{$subitem}{$subsec}{$d}};
                my ($nrfail, $nrall) = split(/\//,$res);
                $logfile =~ s-$urlfilter-$urlpre-;
                if ( $nrall eq '' ) {
                    $class = $res == 0 ? "pass" : $res == 2 ? "run" : "fail";
                    $res=uc($class);
                } else {
                    $class = "ratio";
                }
                $status = "<a href=$logfile title='ref value $nrfail $nrall'>$res</a>";
            }
            print "<td class='$class'>$status</td>";
        }
        print "</tr>";
    }
    }
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
        if ( ! -x $scr || $liv eq 'off' ) {
            next;
        }

        my $top= `dirname $scr`;
        chomp($top);
        my @tlock=<$top/*.lock>;
        my $nrlock=@tlock;
        my $byip=`grep CONFIG_REMOTEIP     $top/build_result/l/env.log | sed -e 's,.*=\\(.*\\),\\1,g' `;
        my $byuser=`grep CONFIG_REMOTEUSER $top/build_result/l/env.log | sed -e 's,.*=\\(.*\\),\\1,g' `;
        chomp($byip); chomp($byuser);
        if ($byip ne "" || $byuser ne "") {
            $byuser="runby:$byuser\@$byip";
        }
        print "<br>Project <a name=$tskid>$tskid</a>:  <font size=+1 color=blue ><b>$tit</b></font><br>\n";
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
        parse_files_by_date(10,"$top/build_result",
		'(\d{2}[0,1][0-9][0-3][0-9])\.txt', '.*/build_result',
		"/build/link/$tskid", $input_params{'idx'});
    }
}

sub get_machine_loadavg {
    my ($usr, $hostip) = ( @_ );

    my $ret=`ssh $usr\@$hostip cat /proc/loadavg`;
    my @load = split(/\s+/, $ret);
    return $load[0] || 0;
    #print "$usr\@$hostip cat /proc/loadavg: $ret ==== $load[0] <br>\n";
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
sub stopbuild_project {
    my $tskid=$input_params{'p'};
    my $scr=$known_tasks{$tskid}{'script' };
    my $hip=$known_tasks{$tskid}{'hostip' };
    my $tit=$known_tasks{$tskid}{'title' };
    my $reb=$known_tasks{$tskid}{'rebuild' };
    my $kil=$known_tasks{$tskid}{'kill' };
    my $pmr=$known_tasks{$tskid}{'pm'};

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
    my $ulevel=userlevel();
    if ($pmr =~ /\b$mission_params{'user'}\b/ ) {
        $ulevel += 10;
    }
    if ( $ulevel >9 ) {
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
    my $pmr=$known_tasks{$tskid}{'pm'};

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

    my $ulevel=userlevel();
    if ($pmr =~ /\b$mission_params{'user'}\b/ ) {
        $ulevel += 10;
    }
    if ( $ulevel >9 ) {
        print "<font color=red size=+1><b>Start killing $hip:$scr</b></font><br>\n";
        print "this may take minutes, please hold this page and<br>\n";
        print "never refresh it, click it or goes back to previous page!<br>\n";
        system "sleep 1 && echo '<pre>' && ssh build\@$hip $scr --kill-running --byip $browserip --byuser $mission_params{'user'} & ";
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
    my $ulevel=userlevel();
    if ( $ulevel == 0 ) {
        print "<font color=red ><b>Sugges you login to this website<br>\n";
        print "After login, build server can trace your actions and give you better supports<br>\n";
        print "Using your c2's account login, when first login, the default password is 123456.<br>\n";
        print "Thanks. (Server).<br>\n";
        print "</b></font>\n";
    }
    system "sleep 1 && echo '<pre>' && ssh build\@$hip $scr --byip $browserip --byuser $mission_params{'user'} & ";
}
sub parse_fs_test_result {

    my ($top, $flag, $tskid)=(@_);
    my $running="idle";
    my ($fs_list, $band_list, $band_max);


    if ( ! -d $top) {
        return 0;
    }
    if ( -f "$top/testing.lock") {
        $running="<font color=red><b>running</b></font>";
    }

    $fs_list = `ls $top/w_*_max.log | sed  s,_max.log,, | sed s,.*_,,`;
    if ( $fs_list eq '' ) {
        return 0;
    }
    my @allfs = split(/\s/,$fs_list);
    my $leadfs=@allfs[0];
    $band_list = `ls $top/r_${leadfs}_*.log | sed  s,.log,, | sed s,.*_,, | sed s,max,,`;

    # advanced sort
    #-------------------------------------------------------------------------
    # @sorted = sort { $a <=> $b } @not_sorted # numerical sort
    # @sorted = sort { $a cmp $b } @not_sorted # ASCII-betical sort
    # @sorted = sort { lc($a) cmp lc($b) } @not_sorted # alphabetical sort
    my @allband = sort { $a <=> $b } split(/\s/,$band_list);
    my $nroffs = @allfs;
    my $nrofband = @allband;

    if ($nroffs < 1 ) {
        return 0;
    }

    my $link="/var/www/html/qa/link";
    unlink("$link/$tskid");
    symlink("$top", "$link/$tskid");

    print "Result: <font color=blue>$top</font> status: $running<br>\n";
    print "Kernel info:";
    system ("grep ^uname= $top/testingenv.log | sed -e 's/.*Linux localhost//g'");
    print "<br>\n";
    print "Result logs: <a href=/qa/link/$tskid/testing.log>progress</a>";
    print " &nbsp;|&nbsp; <a href=/qa/link/$tskid>all logs</a>";
    print " &nbsp;|&nbsp; <a href=/qa/link/$tskid/testingenv.log>configs</a><br>\n";

    my %results_all;
    my %results_max;
    my $results_stk;

    foreach $fs (@allfs) {
    foreach $band (@allband) {
        $results_stk{$band}{$fs}{'r'}=0;
        $results_stk{$band}{$fs}{'w'}=0;
    }}
    foreach $fs (@allfs) {
    foreach $myfop ('r','w') {
    foreach $gen ('all','max') {
       my $log="gen_${myfop}_${fs}_$gen.log";
       if ( ! open (LOG, "$top/$log") ) {
           next;
       }
       my %tmplist;
       while (<LOG>) {
           my ($b,$a,$k) = split(/\s/);
           $tmplist{$b} =[$a, $k ];
       }
       close(LOG);
       my $tidx=0;
       my ($avgband,$avga,$avgk)=(0,0,0);
       my $stepkmax=0;
       my @stepk=@allband;
       foreach my $band (sort { $a <=> $b } keys %tmplist) {
           $tidx += 1;
           my ($va,$vk) = @{$tmplist{$band}};
           $avgband += $band;
           $avga    += $va;
           $avgk    += $vk;
           if($gen eq 'all') {
               $results_all{$tidx}{$fs}{$myfop} =[$band, $va, $vk ];
               if (defined @stepk[1] && $band >= @stepk[1]) {
                   shift (@stepk);
                   $stepkmax = 0;
               }
               if ( $vk > $stepkmax ) {
                   $stepkmax = $vk;
               }
               $results_stk{@stepk[0]}{$fs}{$myfop}=$stepkmax;
           } else {
               $results_max{$tidx}{$fs}{$myfop} =[$band, $va, $vk ];
           }
       }
       if ($tidx > 0) {
           $avgband = $avgband/$tidx;
           $avga    = $avga   /$tidx;
           $avgk    = $avgk   /$tidx;
           if($gen eq 'all') {
               $results_all{0}{$fs}{$myfop} =[$avgband, $avga, $avgk ];
           } else {
               $results_max{0}{$fs}{$myfop} =[$avgband, $avga, $avgk ];
           }
       }
    }}}
    foreach $fs (@allfs) {
        $results_stk{'max'}{$fs}{'rb'}=$results_max{0}{$fs}{'r'}[0];
        $results_stk{'max'}{$fs}{'r'} =$results_max{0}{$fs}{'r'}[2];
        $results_stk{'max'}{$fs}{'wb'}=$results_max{0}{$fs}{'w'}[0];
        $results_stk{'max'}{$fs}{'w'} =$results_max{0}{$fs}{'w'}[2];
    }

    # table 1
    #-----------------------------------------------------------------
    my $nrcols=$nrofband + 4;
    print "<font size=-1px><table border=1>";
    print "<tr><td class=pass align='center' colspan='$nrcols'>Overall FS IO Kernel CPU Usage (%-KB/s)</td></tr>\n";
    print "<tr><td class=ext3b rowspan='2'>Partition</td><td class=ext3b rowspan='2'>Module</td>";
    print "    <td class=ext3b colspan='$nrofband'>Kernel CPU Usage</td><td class=ext3b colspan='2'>Max</td>\n";

    print "<tr>";
    foreach $band (@allband) {
        print "<td class=fat32>$band</td>\n";
    }
    print "<td class=fat32>Bindwidth</td><td class=fat32>K-CPU</td></tr>\n";
    foreach $fs (@allfs) {
        print "<tr><td class=ext3b rowspan='2'>$fs</td><td>Read</td>\n";
        foreach $band (@allband) {
            my $v=$results_stk{$band}{$fs}{'r'};
            if ($v == 0) {
                printf( "<td class=fat32b>-</td>\n");
            } else {
                printf( "<td class=fat32b>%2.2f</td>\n",$v);
            }
        }
        printf( "<td class=ext3b>%6.2f</td>\n",$results_stk{'max'}{$fs}{'rb'});
        printf( "<td class=ext3b>%2.1f</td>\n",$results_stk{'max'}{$fs}{'r'} );
        print "</tr>";

        print "<tr><td>Write</td>\n";
        foreach $band (@allband) {
            my $v=$results_stk{$band}{$fs}{'w'};
            if ($v == 0) {
                printf( "<td class=fat32b>-</td>\n");
            } else {
                printf( "<td class=fat32b>%2.2f</td>\n",$v);
            }
        }
        printf( "<td class=ext3b>%6.2f</td>\n",$results_stk{'max'}{$fs}{'wb'});
        printf( "<td class=ext3b>%2.1f</td>\n",$results_stk{'max'}{$fs}{'w'} );
        print "</tr>";

    }
    print "</table></font>";

    # table 2
    #-----------------------------------------------------------------
    foreach $gen ('max','all') {
        my %results;
        if($gen eq 'all') {
            %results = %results_all;
        } else {
            %results = %results_max;
        }
        my $nrcol=$nroffs * 6;
        print "Detail test data of bandwidth type $gen \n";
        print " [ <a href='###' onclick=\"openShutManager(this,'${tskid}_table${gen}',false,'hide','show')\">hide</a> ] <br>\n";
        print "<div id='${tskid}_table${gen}' style='display:block'>";
        print "<font size=-1px><table border=1>";
        print "<tr><td>proj</td><td align='center' colspan='$nrcol'>$top of $gen</td></tr>";
        print "<tr><td>fs</td>";
        foreach $fs (@allfs) {
           print "<td class=$fs align='center' colspan='6'>$fs</td>";
        }
        print "</tr>";
        print "<tr><td>op</td>";
        foreach $fs (@allfs) {
           print "<td class=$fs align='center' colspan='3'>read</td>";
           print "<td class=$fs align='center' colspan='3'>write</td>";
        }
        print "</tr>";
        print "<tr><td>index</td>";
        foreach $fs (@allfs) {
           print "<td class=${fs}b>bandwidth</td>";
           print "<td class=${fs}a>&nbsp;app&nbsp;</td>";
           print "<td class=${fs}k>kernel</td>";
           print "<td class=${fs}b>bandwidth</td>";
           print "<td class=${fs}a>&nbsp;app&nbsp;</td>";
           print "<td class=${fs}k>kernel</td>";
        }
        print "</tr>";

        foreach $tidx (sort { $a <=> $b } keys %results) {
           print "<tr><td>$tidx</td>";
           foreach $fs (@allfs) {
              my ($rb,$ra,$rk) = @{$results{$tidx}{$fs}{'r'}};
              my ($wb,$wa,$wk) = @{$results{$tidx}{$fs}{'w'}};
              if($tidx == 0) {
                  printf("<td class=$fs>%6d</td>"  ,$rb) ;
                  printf("<td class=$fs>%3.6f</td>",$ra) ;
                  printf("<td class=$fs>%3.6f</td>",$rk) ;
                  printf("<td class=$fs>%6d</td>"  ,$wb) ;
                  printf("<td class=$fs>%3.6f</td>",$wa) ;
                  printf("<td class=$fs>%3.6f</td>",$wk) ;
              } else {
                  print "<td class=pass>$rb</td>";
                  print "<td class=pass>$ra</td>";
                  print "<td class=pass>$rk</td>";
                  print "<td class=pass>$wb</td>";
                  print "<td class=pass>$wa</td>";
                  print "<td class=pass>$wk</td>";
              }
           }
           print "</tr>";
        }
        print "</table></font></div>\n";
    }
}
sub show_fstest {
    our %known_fstests = (
	'fs3' => {
		'title'   => 'jazz2t(tango3) android Nand fs test',
		'homelog' => '/mean/c2/fs-nandroid/test_report',
		},
    );
    my $tskid;
    foreach $tskid (sort keys %known_fstests) {
        my $hlg=$known_fstests{$tskid}{'homelog' };
        if ( -d $hlg ) {
            print "| <a href=#$tskid> $tskid </a>\n";
        }
    }
    print "<br>\n";
    foreach $tskid (sort keys %known_fstests) {
        my $tit=$known_fstests{$tskid}{'title' };
        my $hlg=$known_fstests{$tskid}{'homelog' };
        if ( ! -d $hlg ) {
            next;
        }
        my $results_dir=$hlg;
        my $filter='(\d{6}.\d{2})';
        my $num_days=60;
        my $yangday=$results_dir;
        my @dates;
 
        print "<br>Project <a name=$tskid>$tskid</a>:  <font size=+1 color=blue ><b>$tit</b></font><br>\n";
        if ( ! opendir(DIR, $results_dir) ) {
            print "Die: Couldn't open $results_dir: $!<br>\n";
            return 0;
        }
        my $log_num = grep /^$filter$/i, readdir(DIR);
        close(DIR);
        if ( $log_num > 0 ) {
            if ( $log_num < $num_days ) {
                $num_days = $log_num;
            }
            opendir(DIR, $results_dir);
            @dates = (sort({ $b cmp $a} grep(s/^$filter$/$1/, readdir(DIR))))[0..($num_days-1)];
            close(DIR);
            $yangday="$results_dir/$dates[0]";
            if ( $log_num > 1 ) {
                print "More test results: ";
                my $nr=0;
                for my $d (@dates) {
                    if ( $nr == 0 ) {
                        print "<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\n";
                    }
                    $nr +=1;
                    print " &nbsp;&nbsp;<a href=$home_link?op=fstest&thm=1&d=$d>$d</a> ";
                    if ($nr == 10) {
                        $nr = 0;
                    }
                }
                print "<br>\n";
            }
        }
        if (defined $input_params{'d'}) {
           $yangday="$results_dir/$input_params{'d'}";
        }
 
        parse_fs_test_result("$yangday",0,'t3');
    }
}

sub show_qatest {
    print "<a href='https://access.c2micro.com/index.php/QA#Automation_Plan'>QA's Wiki</a> \n";
    my $tskid;
    my $link="/var/www/html/qa/link";
    foreach $tskid (sort keys %known_qatasks) {
        my $scr=$known_qatasks{$tskid}{'script' };
        my $sta=$known_qatasks{$tskid}{'status' };
        if ( -x $scr && $sta ne 'off' ) {
            print "| <a href=#$tskid> $tskid </a>\n";
        }
    }
    foreach $tskid (sort keys %known_qatasks) {
        my $tit=$known_qatasks{$tskid}{ 'title'   };
        my $cfg=$known_qatasks{$tskid}{ 'config'  };
        my $hip=$known_qatasks{$tskid}{ 'hostip'  };
        my $usr=$known_qatasks{$tskid}{ 'user'    };
        my $hme=$known_qatasks{$tskid}{ 'home'	};
        my $scr=$known_qatasks{$tskid}{ 'script'  };
        my $rst=$known_qatasks{$tskid}{ 'reset'   };
        my $cip=$known_qatasks{$tskid}{ 'clientip'};
        my $sta=$known_qatasks{$tskid}{ 'status'  };

        if ( ! -x $scr ||  $sta eq 'off' ) {
            next;
        }

        my @tlock=<$home/*.lock>;
        my $nrlock=@tlock;
        print "<br>Project <a name=$tskid>$tskid</a>:  <font size=+1 color=blue ><b>$tit</b></font><br>\n";
        print "home:$hip".'@'."$hme<br>\n";
        print "script:$hip".'@'."$scr \n";
        if ( -e "$scr.lock" || $nrlock > 0 ) {
            print ",status: <font color=red><b>running</b></font><br>";
        } else {
            print ",status: <font color=darkblue><b>test inactive</b></font><br>";
        }
        print "<a href=/qa/link/$tskid/>all logs</a> |";
        print "<br>\n";
        system("mkdir -p $link");
	unlink("$link/$tskid");
        symlink("$hme/test_report", "$link/$tskid");
        parse_files_by_date(10,"$hme/test_report",'(\d{4}.\d{2}.\d{2})\.txt','.*/test_report',"/qa/link/$tskid", $input_params{'idx'});
    }
    print "<br>";
    show_fstest();
    print "<br>";
    show_ltptest();
}
sub parse_ltp_test_result {
    my ($top, $flag, $tskid)=(@_);
    my $running="idle";

    if ( ! -d $top) {
        return 0;
    }
    if ( -f "$top/testing.lock") {
        $running="<font color=red><b>running</b></font>";
    }

    my $link="/var/www/html/qa/link";
    unlink("$link/$tskid");
    symlink("$top", "$link/$tskid");

    print "Result: <font color=blue>$top</font> status: $running<br>\n";
    print "Kernel info:";
    system ("grep ^uname= $top/testingenv.log | sed -e 's/.*Linux localhost//g'");
    print "<br>\n";
    print "Result logs: <a href=/qa/link/$tskid/testing.log>progress</a>";
    print " &nbsp;|&nbsp; <a href=/qa/link/$tskid>all logs</a>";
    print " &nbsp;|&nbsp; <a href=/qa/link/$tskid/testingenv.log>configs</a>\n";
    my @pagename=('hide all','all fail/pass','all fail','all pass');
    foreach my $i (0..3) {
    print " &nbsp;|&nbsp; <a href=### onclick=\"aSheetManager(this,'$tskid',$i)\">$pagename[$i]</a>\n";
    }
    print "<br>\n";

    my @results_pass=split(/,/, `grep \ PASS\  $top/result-log | sed 's/.* PASS .*/ PASS, /'` );
    my @results_fail=split(/,/, `grep \ FAIL\  $top/result-log | sed 's/.* FAIL .*/ FAIL, /'` );
    my $nr_pass=@results_pass-1;
    my $nr_fail=@results_fail-1;
    print "total fail / pass:<b><font size=+2 color=red>$nr_fail</font> / <font size=+2 color=blue>$nr_pass</font></b><br>\n";

    my $log="result-log";
    if ( ! open (LOG, "$top/$log") ) {
        return 0;
    }
    my %results_faillist;
    my %results_passlist;
    my %results_all;
    my $findex=0;
    my $pindex=0;
    while (<LOG>) {
        if ( $_ =~ /^.*FAIL.*$/ ) {
            $findex += 1;
            my ($fun,$fp,$ret) = split(/\s+/);
            $results_faillist{$fun} =$ret;
            $results_all{$findex}{'fail'}=[$fun, $ret];
        } elsif ( $_ =~ /^.*PASS.*$/ ) {
            $pindex += 1;
            my ($fun,$fp,$ret) = split(/\s+/);
            $results_passlist{$fun} =$ret;
            $results_all{$pindex}{'pass'}=[$fun, $ret];
        }
    }
    close(LOG);

    my $page_index=1;
    print "Detail result list \n";
    print " [ <a href='###' onclick=\"openShutManager(this,'${tskid}_$page_index',false,'hide','show')\">hide</a> ] <br>\n";
    print "<div id='${tskid}_$page_index' style='display:block'>";
    print "<font size=-1px><table border=1>";
    print "<tr><td>Index</td><td>Function</td><td>Return</td><td>Function</td><td>Return</td></tr>";
    foreach $tidx (sort { $a <=> $b } keys %results_all) {
        my ($pf,$pr,$ff,$fr) = (
            $results_all{$tidx}{'pass'}[0],$results_all{$tidx}{'pass'}[1],
            $results_all{$tidx}{'fail'}[0],$results_all{$tidx}{'fail'}[1]);
        my ($clsps,$clsfl) = ('','');
        if (defined $results_all{$tidx}{'pass'}[0]) {
            $clsps='class=pass'; 
        } else { $pf='&nbsp;';$pr='&nbsp;';
        }
        if (defined $results_all{$tidx}{'fail'}[0]) {
            $clsfl='class=fail'; 
        } else { $ff='&nbsp;';$fr='&nbsp;';
        }
        print "<tr><td>$tidx</td><td $clsfl>$ff</td><td $clsfl>$fr</td>";
        print "<td $clsps>$pf</td><td $clsps>$pr</td></tr>";
    }
    print "</table></font>";
    print "</div>";
    $page_index += 1;

    foreach $fp ('fail','pass') {
        my %mylist;
        if ($fp eq 'fail') {
            %mylist=%results_faillist;
        } else {
            %mylist=%results_passlist;
        }
        print "Detail $fp list \n";
        print " [ <a href='###' onclick=\"openShutManager(this,'${tskid}_$page_index',false,'hide','show')\">show</a> ] <br>\n";
        print "<div id='${tskid}_$page_index' style='display:none'>";
        print "<font size=-1px><table border=1>";
        print "<tr><td>Index</td><td>Function</td><td>Return</td></tr>";
        my $tidx=0;
        foreach $f (sort keys %mylist) {
           $tidx +=1;
           print "<tr><td>$tidx</td><td class=$fp>$f</td><td class=$fp>$mylist{$f}</td></tr>";
        }
        print "</table></font>";
        print "</div>";
        $page_index += 1;
    }
}
sub show_ltptest {
    our %known_ltptests = (
	'ltp3up' => {
		'title'   => 'jazz2t(tango3) android ltp test',
		'homelog' => '/mean/c2/nfsroot/tango3-rootfs/ltp/ltp-full-20090228/test_report',
		},
	'ltp3smp' => {
		'title'   => 'jazz2t(tango3) android ltp test',
		'homelog' => '/mean/c2/nfsroot/tango3-rootfs/ltp/ltp-full-20090228/test_reportsmp',
		},
	'ltp4up' => {
		'title'   => 'jazz2(tango) android ltp test',
		'homelog' => '/mean/c2/nfsroot/jazz2-rootfs/ltp/ltp-full-20090228/test_report',
		},
	'ltp4smp' => {
		'title'   => 'jazz2(tango) android ltp test',
		'homelog' => '/mean/c2/nfsroot/jazz2-rootfs/ltp/ltp-full-20090228/test_reportsmp',
		},
    );
    my $tskid;
    foreach $tskid (sort keys %known_ltptests) {
        my $hlg=$known_ltptests{$tskid}{'homelog' };
        if ( -d $hlg ) {
            print "| <a href=#$tskid> $tskid </a>\n";
        }
    }
    print "<br>\n";
    foreach $tskid (sort keys %known_ltptests) {
        my $tit=$known_ltptests{$tskid}{'title' };
        my $hlg=$known_ltptests{$tskid}{'homelog' };
        if ( ! -d $hlg ) {
            next;
        }

        my $results_dir=$hlg;
        my $filter='(\d{6}.\d{2})';
        my $num_days=60;
        my $yangday=$results_dir;
        my @dates;
 
        print "<br>Project <a name=$tskid>$tskid</a>:  <font size=+1 color=blue ><b>$tit</b></font><br>\n";
        if ( ! opendir(DIR, $results_dir) ) {
            print "Die: Couldn't open $results_dir: $!<br>\n";
            return 0;
        }
        my $log_num = grep /^$filter$/i, readdir(DIR);
        close(DIR);
        if ( $log_num > 0 ) {
            if ( $log_num < $num_days ) {
                $num_days = $log_num;
            }
            opendir(DIR, $results_dir);
            @dates = (sort({ $b cmp $a} grep(s/^$filter$/$1/, readdir(DIR))))[0..($num_days-1)];
            close(DIR);
            $yangday="$results_dir/$dates[0]";
            if ( $log_num > 1 ) {
                print "More test results: ";
                my $nr=0;
                for my $d (@dates) {
                    if ( $nr == 0 ) {
                        print "<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\n";
                    }
                    $nr +=1;
                    print " &nbsp;&nbsp;<a href=$home_link?op=ltptest&thm=1&d=$d>$d</a> ";
                    if ($nr == 10) {
                        $nr = 0;
                    }
                }
                print "<br>\n";
            }
        }
        if (defined $input_params{'d'}) {
           $yangday="$results_dir/$input_params{'d'}";
        }
 
        parse_ltp_test_result("$yangday",0,"$tskid");
    }
}
