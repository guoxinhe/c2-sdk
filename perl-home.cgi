#!/usr/bin/perl

use CGI::Cookie;
use CGI qw(:standard :escapeHTML -nosticky);
#our $cgi=new CGI;

our $home_link='perl-home.cgi';
our $login_link='perl-login.cgi';
# See what incoming cookies we have!
our %input_params = (
    'user' => 'guest' ,
    'pswd' => '123456',
    'apps' => 'email' ,
);

%cookies = fetch CGI::Cookie();
foreach $c (keys %cookies) {
        $v = $cookies{$c} -> value();
    if ( $c eq "user" ) {
        $input_params{'user'}=$v;
    } 
    if ( $c eq "pswd" ) {
        $input_params{'pswd'}=$v;
    } 
    if ( $c eq "apps" ) {
        $input_params{'apps'}=$v;
    } 
}


our %known_cookies = (
    #'expires' => '(optional) +60s +20m +5h nowimmediately +5M +1y',
    'user' => {'value'=>'guest' ,'domain'=>'.build','expires'=>'+1y','path'=>'/','secure'=> 0,},
    'pswd' => {'value'=>'123456','domain'=>'.build','expires'=>'+3s','path'=>'/','secure'=> 0,},
    'apps' => {'value'=>'email' ,'domain'=>'.build','expires'=>'+1y','path'=>'/','secure'=> 0,},
);
foreach $c (keys %known_cookies) {
    my $value  =$known_cookies{$c}{'value'  };
    my $expires=$known_cookies{$c}{'expires'};
    unless (grep (/^$c$/,keys %cookies)) {
        sendcookie($c,$value,$expires);
    }
}
if ( $ENV{'REQUEST_METHOD'} eq 'GET' ) {
    #for 'get' method:
    if ( $ENV{'QUERY_STRING'} ne '' ) {
        #$input_params{'op'} = $cgi->param('op');
    my $buffer=$ENV{'QUERY_STRING'};
    @pairs = split(/&/, $buffer);
    foreach $pair (@pairs){
        ($name, $value) = split(/=/, $pair);
        $value =~ tr/+/ /;
        $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $input_params{$name} = $value;
    }
    }
    
} else {
    #for 'post' form:
    my $buffer;
    read (STDIN, $buffer, {'CONTENT_LENGTH'});
    @pairs = split(/&/, $buffer);
    foreach $pair (@pairs){
        ($name, $value) = split(/=/, $pair);
        $value =~ tr/+/ /;
        $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $input_params{$name} = $value;
    }
}

# Go!
#----------------------------------------------------------------------------
html_head();

if ( $input_params{'user'} eq 'guest' ) {
    print "please login<br>\n";
    html_login();
} else {
    print "Welcome $input_params{'user'}<br>\n";
}

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
sub html_list_input_params {
print <<HTML;
<table border=1><tr><td>Name</td><td>Value</td></tr>
HTML
    my $i;
    foreach $i (sort keys %input_params) {
        my $v=$input_params{$i};
        if ( $v eq '') {
            $v='-';
        }
        print "<tr><td>$i</td><td>$v</td></tr>\n"
    }
print "</table>";

print <<HTML;
<table border=1><tr><td>Name</td><td>Value</td></tr>
HTML
foreach (sort keys %ENV) {
    #print "$_ = $ENV{$_}<br>\n";
    print "<tr><td>$_</td><td>$ENV{$_}</td></tr>\n"
}
print "</table>";

}
sub html_login {
print <<HTML;
<form action="$login_link?op=login" method="POST">
<center>Please login</center>
<center>
<table border="0" cellpadding="3" cellspacing="3">
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
<title>Monitor home page</title>
<style type="text/css">
<!--/* <![CDATA[ */
<!--
    body  {font-family: Arial }
    a:link {color:black}
    a:visited {color:black}
    a:hover {color:blue}
    a:active {color:green}
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
| <a href=$home_link>Home</a> 
HTML
    if ( $input_params{'user'} ne 'guest' ) {
        print "| <a href=$login_link?op=logout>Logout</a> "
    }
    print "<hr>";
}
sub html_tail {
print "<hr> more webpage(cgi) debug info";
print " <a href='###' onclick=\"openShutManager(this,'moretext',false,'hide','show')\">show</a>";
print "<p id='moretext' style='display:none'>";
html_list_input_params();
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
print "</p>";
print <<HTML;
<br>
Copyright, all rights reserved.
</body>
HTML
}
