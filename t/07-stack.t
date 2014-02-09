#!/usr/bin/env perl
use strict;
use warnings; no warnings 'void';

use lib 'lib';
use lib 't/lib';
use Devel::CommonDB::TestRunner;

run_test(
    57,
    sub {
        foo(1,2,3);                 # line 12: void
        sub foo {
            my @a = Bar::bar();     # line 14: list
        }
        sub Bar::bar {
            &Bar::baz;              # line 17: list
        } 
        package Bar;
        sub baz {
            my $a = eval {          # line 21: scalar
                eval "quux()";      # line 22: scalar
            }
        }
        sub AUTOLOAD {
            $DB::single=1;
            27;                     # scalar
        }
    },
    \&check_stack,
    'done'
);

sub check_stack {
    my($db, $loc) = @_;
    my $stack = $db->stack();

    Test::More::ok($stack, 'Get execution stack');

    my $filename = __FILE__;
    my @expected = (
        {   package     => 'Bar',
            filename    => $filename,
            line        => 27,
            subroutine  => 'Bar::AUTOLOAD',
            hasargs     => 1,
            wantarray   => '',
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => 'quux',
            subname     => 'AUTOLOAD',
            args        => [],
        },
        {   package     => 'Bar',
            filename    => qr/\(eval \d+\)\[$filename:22\]/,
            line        => 1,   # line 1 if the eval text
            subroutine  => '(eval)',
            hasargs     => 0,
            wantarray   => '',
            evaltext    => $^V lt v5.18 ? "quux()\n;" : 'quux()',
            evalfile    => $filename,
            evalline    => 22,
            is_require  => '',  # false but not undef because it is a string eval
            autoload    => undef,
            subname     => '(eval)',
            args        => [],
        },
        {   package     => 'Bar',
            filename    => $filename,
            line        => 22,
            subroutine  => '(eval)',
            hasargs     => 0,
            wantarray   => '',
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
            line        => 21,   
            subroutine  => 'Bar::baz',
            hasargs     => $^V lt v5.12 ? 0 : '', # because it's called as &Bar::baz;
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
            line        => 17,
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
            line        => 14,
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
        # two frames inside run_test
        {   package     => 'main',
            filename    => $filename,
            line        => 12,
            subroutine  => "main::__ANON__[$filename:29]",
            hasargs     => 1,
            wantarray   => undef,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => undef,
            subname     => '__ANON__',
            args        => [],
        },
        {   package =>  'Devel::CommonDB::TestRunner',
            filename    => qr(t/lib/Devel/CommonDB/TestRunner\.pm$),
            line        => '__DONT_CARE__',
            subroutine  => 'Devel::CommonDB::TestRunner::run_test',
            hasargs     => 1,
            wantarray   => undef,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => undef,
            subname     => 'run_test',
            args        => '__DONT_CARE__',
        },
 
        {   package     => 'main',
            filename    => $filename,
            line        => 30,
            subroutine  => 'main::MAIN',
            hasargs     => 1,
            wantarray   => undef,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => undef,
            subname     => 'MAIN',
            args        => ['--test'],
        },
    );

    Test::More::is($stack->depth, scalar(@expected), 'Expected number of stack frames');

    for(my $framenum = 0; my $frame = $stack->frame($framenum); $framenum++) {
        check_frame($frame, $expected[$framenum]);
    }

    my $iter = $stack->iterator();
    Test::More::ok($iter, 'Stack iterator');
    for(my $framenum = 0; my $frame = $iter->(); $framenum++) {
        check_frame($frame, $expected[$framenum], 'iterator');
    }
}

sub check_frame {
    my($got_orig, $expected_orig, $msg) = @_;
    my %got_copy = %$got_orig;
    my %expected_copy = %$expected_orig;

    { no warnings 'uninitialized';
        $msg = (defined $msg)
                ? sprintf("%s:%s $msg", @expected_copy{'filename','line'})
                : sprintf("%s:%s", @expected_copy{'filename','line'});
    }

    remove_dont_care(\%expected_copy, \%got_copy);

    Test::More::ok(exists($got_copy{hints})
            && exists($got_copy{bitmask})
            && exists($got_copy{level}),
            "Frame has hints, bitmask and level: $msg");
    my($level) = delete @got_copy{'level','hints','bitmask'};

    my $got_filename = delete $got_copy{filename};
    my $expected_filename = delete $expected_copy{filename};
    if (ref $expected_filename) {
        Test::More::like(
                $got_filename,
                $expected_filename,
                "Execution stack frame filename matches: $msg");
    } else {
        Test::More::is($got_filename,
                        $expected_filename,
                        "Execution stack frame filename matches: $msg");
    }

        
    Test::More::is_deeply(\%got_copy, \%expected_copy, "Execution stack frame matches for $msg");
}

sub remove_dont_care {
    my($expected, $got) = @_;
    foreach my $k ( keys %$expected ) {
        no warnings 'uninitialized';
        if ($expected->{$k} eq '__DONT_CARE__') {
            delete $expected->{$k};
            delete $got->{$k};
        }
    }
}
