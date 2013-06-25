#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';
use Test::More tests => 12;

5;
foo();
7;
sub foo {
    9;
}


package TestDB;

use base 'Devel::CommonDB';

my @tests;
BEGIN {
    @tests = (
        { package => 'main', subroutine => 'MAIN', line => 6, filename => __FILE__ },
        { package => 'main', subroutine => 'MAIN', line => 7, filename => __FILE__ },
        { package => 'main', subroutine => 'MAIN', line => 8, filename => __FILE__ },
    );
    
    TestDB->attach();
}

sub notify_stopped {
    my($class, $loc) = @_;
    
    my $next_test = shift @tests;
    exit unless $next_test;

    Test::More::note('Testing line '.$next_test->{line});

    foreach my $prop ( keys %$next_test ) {
        Test::More::is($loc->$prop, $next_test->{$prop}, "Location $prop");
    }
}

sub poll {
    return scalar(@tests);
}

sub idle {
    TestDB->stepover();
    1;
}


