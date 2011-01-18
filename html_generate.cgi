#!/usr/bin/perl

use CGI qw/:standard/;

use strict;
use Fcntl qw(:seek);

my $num_days = 9;
my $total=0;

my $CSS = <<EOCSS;
<!--
td {text-align: center}
table {background: lightgrey}
td.category {vertical-align:top}

.pass {background: #00ff00; font-weight:bold}
.fail {background: red;  font-weight:bold}
.na   {background: grey}
-->
EOCSS

sub check_for_results_string {
  my $log = shift;

  open (LOG, $log) or return (undef, undef);

  seek (LOG, -200, SEEK_END);

  my $tail;

  {
    local $/ = undef;

    $tail = <LOG>;
  }

  close (LOG);

  my ($n_warning, $n_error) =
    ($tail =~ m-^BUILD RESULTS: warnings (\d+)/(\d+) errors-m);

  return ($n_warning, $n_error);
}

sub print_top_results {

  my $results_dir; 
  my $tree_prefix;
  my $sdk_target_arch;
  my $user;

  if (defined($ENV{SDK_RESULTS_DIR})) {
    $results_dir = $ENV{SDK_RESULTS_DIR};
  }else{
    $results_dir = "$ENV{PWD}/../build_result";
  }

  if (defined($ENV{TREE_PREFIX})) {
    $tree_prefix = $ENV{TREE_PREFIX};
  }else{
    $tree_prefix = "msp_dev";
  }

  if (defined($ENV{SDK_TARGET_ARCH})) {
    $sdk_target_arch = $ENV{SDK_TARGET_ARCH};
  }else{
    $sdk_target_arch = "jazzb";
  }

  if (defined($ENV{SDK_CVS_USER})) {
    $user = $ENV{SDK_CVS_USER};
  }else{
    $user = "roger";
  }

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

  print "Click on <b>FAIL</b> link to see log of failures<br>";

  print "<table border=1>";
  print "<tr><th>Category</th><th>" .
    join ("</th><th>", @dates) . "</th></tr>";

    my $newrow = 0;

    for my $test (keys (%results)) {
      print "<tr>" if ($newrow);

      # Make test red if the most recent test failed
      my $testclass = "na";
      if (exists($results{$test}{$dates[0]})) {
        $testclass = $results{$test}{$dates[0]}[0] == 0 ? "pass" : "fail";
      }


      print "<td class=${testclass}>$test</td>";

      for my $d (@dates) {
        my $class = "na";
        my $status = "";

        if (exists($results{$test}{$d})) {
          my ($res, $log) = @{$results{$test}{$d}};
          $class = $res == 0 ? "pass" : "fail";

          my ($n_warning, $n_error) = check_for_results_string($log);

          $status = ($n_error) ? "${n_warning}/${n_error}" : uc($class);

          $log =~ s-$results_dir-https://access.c2micro.com/~${user}/${sdk_target_arch}_${tree_prefix}_logs/-;

          $status = "<a href='$log' title='gettin jiggy'>${status}</a>";
        }
        print "<td class='${class}'>${status}</td>";
      }
      print "</tr>";
      $newrow = 1;
    }
  

  print "</table>";

}

print header;
print start_html(-title=>"C2 $ENV{SDK_TARGET_ARCH} SDK Daily Build Results",
                 -style=>{'code'=>$CSS});

print h1("C2 $ENV{SDK_TARGET_ARCH} SDK Daily Build Results");

print_top_results();

print end_html;
