#!/usr/bin/perl

use CGI::Cookie;

our $home_link=$ENV{'SCRIPT_NAME'};
our $bash_home='/var/www';
our %input_params = (
    'msid'        => 'none'    , #should get from cookie
    'user'        => 'guest'   , #should get from cookie
    'pswd'        => 'none'    , #should get from cookie
    'op'          => 'default' ,
    'debug'       => 'off'     ,
    'webtitle'    => 'Perl web test page',
);
our %mission_params = (
    'msid'        => 'none'    ,
    'user'        => 'guest'   ,
    'pswd'        => 'none'    ,
    'result'      => ''        ,
);
our %known_cookies = ( #cookies that must saved in client side. readonly variable
    #'expires' => '(optional) +60s +20m +5h nowimmediately +5M +1y',
    'msid' => {'value'=>'none'   ,'domain'=>'.build','expires'=>'+1y','path'=>'/','secure'=> 0,},
    'user' => {'value'=>'guest'  ,'domain'=>'.build','expires'=>'+1y','path'=>'/','secure'=> 0,},
    'pswd' => {'value'=>'none'   ,'domain'=>'.build','expires'=>'+1y','path'=>'/','secure'=> 0,},
);
our %actions = (
	'loginpage'  	=> \&func_loginpage,
	'myprofile'  	=> \&func_myprofile,
	'login'  	=> \&func_login,
	'logout'  	=> \&func_logout,
        'default'     	=> \&func_default,
);
our %menu_links = (
        'Home'       =>  "$home_link",
        'admin'      =>  "$home_link?op=admin",
        'build'      =>  "$home_link?op=build",
        'license'    =>  "$home_link?op=license",
        'help'       =>  "$home_link?op=help",
);
our %friendly_links = (
        "build195"      => 'http://10.16.13.195',
        "build196"      => 'http://10.16.13.196',
        'license'       => 'http://10.16.13.195/build/project.cgi'
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
    }
    if ( $input_params{'password'} eq 'none'  ||
         $input_params{'password'} eq ''      ){
         $check_result='fail';
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
$input_params{'webtitle'} .= " op: ".$input_params{'op'};
# Go!
#----------------------------------------------------------------------------
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
sub html_login {
print <<HTML;
<center><form action="$home_link?op=login" method="POST">
Please login(method: post)
<table border="0" cellpadding="3" cellspacing="3">
    <tr><td>Username</td><td><input type="text"     size="32" name="username" value="$input_params{username}"></td></tr>
    <tr><td>Password</td><td><input type="password" size="32" name="password" value="$input_params{password}"></td></tr>
    <tr><td align="center" colspan="2"><input type="submit"   name="op" value="login"></td></tr>
</table></form></center>

<center><form action="$home_link?op=login" method="GET">
Please login(method: get)
<table border="0" cellpadding="3" cellspacing="3">
    <tr><td>Username</td><td><input type="text"     size="32" name="username" value="$input_params{username}"></td></tr>
    <tr><td>Password</td><td><input type="password" size="32" name="password" value="$input_params{password}"></td></tr>
    <tr><td align="center" colspan="2"><input type="submit"   name="op" value="login"></td></tr>
</table></form></center>
HTML
}
sub html_head {
print "Content-type: text/html\n\n";
print <<HTML;
<html>
<head>
<title>$input_params{webtitle}</title>
<style type="text/css">
<!--/* <![CDATA[ */
<!--
    body  {font-family: Arial }
    a:link    {color:black}
    a:visited {color:black}
    a:hover   {color:blue}
    a:active  {color:green}
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
</script>
</head>
<body>
HTML
    #list the top level menu
    foreach $i (sort keys %menu_links) {
        my $v=$menu_links{$i};
        print "| &nbsp;<a href=$v>$i</a>&nbsp; \n"
    }
    if ( $mission_params{'user'} eq 'guest' ) {
        print "| <a href=$home_link?op=loginpage>Login</a> ";
    } else {
        print "| <a href=$home_link?op=logout>Logout</a> ";
        print " <a href=$home_link?op=myprofile>$mission_params{'user'}</a> ";
    }

    print "<hr>";
}

sub html_tail {
    my $i;
    print "<hr> more webpage(cgi) debug info";
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
    print "<br>\n";
    foreach $i (sort keys %friendly_links) {
        my $v=$friendly_links{$i};
        print "| &nbsp;<a href=$v>$i</a>&nbsp; \n"
    }

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
    print "Welcome $mission_params{'user'}<br><pre>\n";
    system ("id $mission_params{'user'}");
    system ("uname -a");
    print "</pre>\n";
    
}
sub func_default {
    print "the op is $input_params{'op'}<br>\n";
}

# Your extension code goes here:)
#----------------------------------------------------------------------------
