#!/usr/bin/env perl
use strict;
use warnings; no warnings 'void';

use lib 'lib';
use lib 't/lib';
use Devel::Chitin::TestRunner;

our($id_1, $id_2, $id_3, $id_4, $id_5); my $main_id = $Devel::Chitin::stack_uuids[0]->[-1];
run_test(
    60,
    sub {
        $id_1 = $Devel::Chitin::stack_uuids[-1]->[-1];
        foo(1,2,3);                 # line 14: void
        sub foo {
            $id_2 = $Devel::Chitin::stack_uuids[-1]->[-1];
            my @a = Bar::bar();     # line 17: list
        }
        sub Bar::bar {
            $id_3 = $Devel::Chitin::stack_uuids[-1]->[-1];
            &Bar::baz;              # line 21: list
        } 
        package Bar;
        sub baz {
            $id_4 = $Devel::Chitin::stack_uuids[-1]->[-1];
            my $a = eval {          # line 26: scalar
                eval "quux()";      # line 27: scalar
            };
        }
        sub AUTOLOAD {
            $id_5 = $Devel::Chitin::stack_uuids[-1]->[-1];
            $DB::single=1;
            33;                     # scalar
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
            line        => 33,
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
            id          => $id_5,
        },
        {   package     => 'Bar',
            filename    => qr/\(eval \d+\)\[$filename:27\]/,
            line        => 1,   # line 1 if the eval text
            subroutine  => '(eval)',
            hasargs     => 0,
            wantarray   => '',
            evaltext    => $^V lt v5.18 ? "quux()\n;" : 'quux()',
            evalfile    => $filename,
            evalline    => 27,
            is_require  => '',  # false but not undef because it is a string eval
            autoload    => undef,
            subname     => '(eval)',
            args        => [],
            id          => '__DONT_CARE__',  # we'll check eval frame IDs in uuids_are_distinct()
        },
        {   package     => 'Bar',
            filename    => $filename,
            line        => 27,
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
            id          => '__DONT_CARE__', # we'll check eval frame IDs in ids_are_distinct()
        },
        {   package     => 'Bar',
            filename    => $filename,
            line        => 26,
            subroutine  => 'Bar::baz',
            hasargs     => '', # because it's called as &Bar::baz;
            wantarray   => 1,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => undef,
            subname     => 'baz',
            args        => [],
            id          => $id_4,
        },
        {   package     => 'main',
            filename    => $filename,
            line        => 21,
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
            id          => $id_3,
        },
        {   package     => 'main',
            filename    => $filename,
            line        => 17,
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
            id          => $id_2,
        },
        # two frames inside run_test
        {   package     => 'main',
            filename    => $filename,
            line        => 14,
            subroutine  => "main::__ANON__[$filename:35]",
            hasargs     => 1,
            wantarray   => undef,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => undef,
            subname     => '__ANON__',
            args        => [],
            id          => $id_1,
        },
        {   package =>  'Devel::Chitin::TestRunner',
            filename    => qr(t/lib/Devel/Chitin/TestRunner\.pm$),
            line        => '__DONT_CARE__',
            subroutine  => 'Devel::Chitin::TestRunner::run_test',
            hasargs     => 1,
            wantarray   => undef,
            evaltext    => undef,
            evalfile    => undef,
            evalline    => undef,
            is_require  => undef,
            autoload    => undef,
            subname     => 'run_test',
            args        => '__DONT_CARE__',
            id          => '__DONT_CARE__',
        },
 
        {   package     => 'main',
            filename    => $filename,
            line        => 36,
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
            id          => $main_id,
        },
    );

    Test::More::is($stack->depth, scalar(@expected), 'Expected number of stack frames');

    my @ids;
    for(my $framenum = 0; my $frame = $stack->frame($framenum); $framenum++) {
        check_frame($frame, $expected[$framenum]);
        push @ids, [$framenum, $frame->id];
    }
    ids_are_distinct(\@ids);

    my $iter = $stack->iterator();
    Test::More::ok($iter, 'Stack iterator');
    my @iter_ids;
    for(my $framenum = 0; my $frame = $iter->(); $framenum++) {
        check_frame($frame, $expected[$framenum], 'iterator');
        push @iter_ids, [$framenum, $frame->id];

    }
    Test::More::is_deeply(\@iter_ids, \@ids, 'Got the same ids');

    # Get the stack again, ids should be the same
    my $stack2 = $db->stack();
    my @ids2;
    for (my $framenum = 0; my $frame = $stack2->frame($framenum); $framenum++) {
        push @ids2, [ $framenum, $frame->id];
    }
    Test::More::is_deeply(\@ids2, \@ids, 'ids are the same getting another stack object');
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

sub ids_are_distinct {
    my $id_records = shift;

    my %id_counts;
    my %id_to_frame;
    foreach my $record ( @$id_records ) {
        my($frameno, $id) = @$record;
        $id_counts{ $id }++;

        $id_to_frame{$id} ||= [];
        push @{$id_to_frame{ $id } }, $frameno
    }

    my @duplicate_ids = grep { $id_counts{$_} > 1 } keys %id_counts;
    Test::More::ok(! @duplicate_ids, 'IDs are distinct')
        or Test::More::diag('Frames with duplicates: ', join(' and ', map { join(',', @{$id_to_frame{$_}}) } @duplicate_ids));
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
