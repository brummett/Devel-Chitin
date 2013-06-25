#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

foo(1,2,3);                 # line 5
sub foo {
    my @a = Bar::bar();     # line 7
}
sub Bar::bar {
    &Bar::baz;              # line 10
} 
package Bar;
sub baz {
    my $a = eval {          # line 14
        eval "quux()";      # line 15
    }
}
sub AUTOLOAD {
    $DB::single=1;
    20;
}

package main;

use lib 't/lib';
use TestDB;
use Test::More tests => 35;

sub test_1 {
    my($tester, $loc) = @_;
    is_deeply($tester->current_location(),
        {   'package'   => 'main',
            filename    => __FILE__,
            subroutine  => 'MAIN',
            line        => 5 },
        'Current location at start');
    ok($tester->continue(), 'continue');
}

sub test_2 {
    my($tester, $loc) = @_;
    my $stack = $tester->stack();
    ok($stack, 'Get execution stack');

    my $filename = __FILE__;
    my @expected = (
        {   package     => 'Bar',
            filename    => $filename,
            line        => 20,
            subroutine  => 'Bar::AUTOLOAD',
            hasargs     => 1,
            wantarray   => 0,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => 'quux',
            subname     => 'AUTOLOAD',
            args        => [],
        },
        {   package     => 'Bar',
            filename    => qr/\(eval \d+\)\[$filename:15\]/,
            line        => 1,   # line 1 if the eval text
            subroutine  => '(eval)',
            hasargs     => 0,
            wantarray   => 0,
            evaltext    => "quux()\n;",
            evalfile    => $filename,
            evalline    => 15,
            is_require  => '',  # false but not undef because it is a string eval
            autoload    => undef,
            subname     => '(eval)',
            args        => [],
        },
        {   package     => 'Bar',
            filename    => $filename,
            line        => 15,
            subroutine  => '(eval)',
            hasargs     => 0,
            wantarray   => 0,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => undef,
            subname     => '(eval)',
            args        => [],
        },
        {   package     => 'Bar',
            filename    => $filename,
            line        => 14,   
            subroutine  => 'Bar::baz',
            hasargs     => 0,
            wantarray   => 1,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => undef,
            subname     => 'baz',
            args        => [],
        },
        {   package     => 'main',
            filename    => $filename,
            line        => 10,
            subroutine  => 'Bar::bar',
            hasargs     => 1,
            wantarray   => 1,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => undef,
            subname     => 'bar',
            args        => [],
        },
        {   package     => 'main',
            filename    => $filename,
            line        => 7,
            subroutine  => 'main::foo',
            hasargs     => 1,
            wantarray   => undef,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => undef,
            subname     => 'foo',
            args        => [1,2,3],
        },
        {   package     => 'main',
            filename    => $filename,
            line        => 5,
            subroutine  => 'main::MAIN',
            hasargs     => 1,
            wantarray   => 0,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => undef,
            subname     => 'MAIN',
            args        => [],
        },
    );

    is($stack->depth, scalar(@expected), 'Expected number of stack frames');

    for(my $framenum = 0; my $frame = $stack->frame($framenum); $framenum++) {
        check_frame($frame, $expected[$framenum], $framenum);
    }

    my $iter = $stack->iterator();
    ok($iter, 'Stack iterator');
    my $i = 0;
    while (my $frame = $iter->()) {
        check_frame($frame, $expected[$i], "$i iterator");
        $i++;
    }
            
    $tester->__done__;
}

sub check_frame {
    my($got_orig, $expected_orig, $msg) = @_;
    my %got_copy = %$got_orig;
    my %expected_copy = %$expected_orig;

    ok(exists($got_copy{hints})
            && exists($got_copy{bitmask})
            && exists($got_copy{level}),
            "Frame has hints, bitmask and level for $msg");
    delete @got_copy{'hints','bitmask','level'};

    if (ref($expected_copy{filename})) {
        like(   delete $got_copy{filename},
                delete $expected_copy{filename},
                "Execution stack frame filename matches for $msg");
    }
    is_deeply(\%got_copy, \%expected_copy, "Execution stack frame matches for $msg");
}
