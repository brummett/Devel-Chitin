#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

5;
6;
for (my $i = 0; $i < 2; $i++) {
    foo();
}
10;
sub foo {
    12;
}

use Test::More tests => 9;

package TestDB;
use base 'Devel::CommonDB';
my @trace;
BEGIN {
    @trace = (
        { package => 'main', subroutine => 'MAIN', line => 5, filename => __FILE__ },
        { package => 'main', subroutine => 'MAIN', line => 6, filename => __FILE__ },
        # for loop initialization
        { package => 'main', subroutine => 'MAIN', line => 9, filename => __FILE__ },
        # for loop condition
        { package => 'main', subroutine => 'MAIN', line => 7, filename => __FILE__ },
        # about to call foo()
        { package => 'main', subroutine => 'MAIN', line => 8, filename => __FILE__ },
        { package => 'main', subroutine => 'main::foo', line => 12, filename => __FILE__ },
        # About to call foo() again
        { package => 'main', subroutine => 'MAIN', line => 8, filename => __FILE__ },
        { package => 'main', subroutine => 'main::foo', line => 12, filename => __FILE__ },
        # done
        { package => 'main', subroutine => 'MAIN', line => 10, filename => __FILE__ },
    );
    TestDB->attach();
    TestDB->trace(1);
}

sub notify_trace {
    my($class, $loc) = @_;

    my $next_test = shift @trace;
    exit unless $next_test;

    Test::More::is_deeply($loc, $next_test, 'Trace for line '.$next_test->{line});
}

