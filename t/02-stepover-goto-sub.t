#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

do_goto();
1;
sub do_goto {
    goto \&goto_sub;
}
sub goto_sub {
    1;
}

use Test::More tests => 2;
use TestDB;

sub test_1 {
    my($tester, $loc) = @_;
    # step over a sub that uses goto to leave a subroutine for a higher
    # frame
    ok($tester->stepover(), 'Step over do_goto');
}

sub test_2 {
    my($tester, $loc) = @_;
    is($loc->line, 6, 'Stopped on line 6');
    $tester->__done__;
}
    
