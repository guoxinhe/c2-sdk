#!/usr/bin/perl

use strict;
use warnings;

sub days {return shift() * 3600 * 24}

my %haslnk;
my @oldfiles;

sub main {
  if (@ARGV < 2) {
    die "usage: $0 <directory> <age in days to clean up>\n"
  }

  chdir($ARGV[0]);

  for my $f (<*>) {
    if (-l $f) {
      $haslnk{readlink($f)} = 1;
    } elsif ((time() - (stat($f))[9]) > days($ARGV[1])) {
      push @oldfiles, $f;
    }
  }

  for my $f (@oldfiles) {
    next if $haslnk{$f};
    print "removing $f...\n";
    system("rm -rf $f");
  }
}

&main;
