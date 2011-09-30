#!/usr/bin/perl

use CGI::Cookie;

# See what incoming cookies we have!

%cookies = fetch CGI::Cookie();
$ctab = "It is ".time()." i.e. ".localtime()."<BR>\n";
$ctab .= "<table border=1>";
$ctab .= "<tr><td>Name</td><td>Value</td></tr>\n";

foreach $c (keys %cookies) {
        $v = $cookies{$c} -> value();
        $ctab .= "<tr><td>$c</td><td>$v</td></tr>\n";
        }

$ctab .= "</table><BR><BR>";

# Send out any new cookies that we need!

%want = ("short_term" => "+10m", "nonpersistant" => "",
        "long_term" => "+240M");

foreach $c (keys %want) {
        unless (grep (/^$c$/,keys %cookies)) {
                sendcookie($c,time(),$want{$c});
                $ctab .= "Set cookie called $c<BR>\n";
        } else {
                $ctab .= "$c already set<BR>\n";
                }
        }

print "Content-type: text/html\n\n";
print $ctab;

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
