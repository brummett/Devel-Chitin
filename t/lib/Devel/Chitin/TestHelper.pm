package Devel::Chitin::TestHelper;

use strict;
use warnings;

use Test2::V0;
use Test2::API qw( context_do context run_subtest test2_add_callback_testing_done);
use base 'Devel::Chitin';

use Exporter 'import';
our @EXPORT_OK = qw(ok_location
                    ok_at_end
                    db_step db_continue db_stepout
                );

my @TEST_QUEUE;

test2_add_callback_testing_done(sub {
    if (@TEST_QUEUE) {
        ok(0, 'There were ' . scalar(@TEST_QUEUE) . ' tests remaining in the queue');
    }
});

sub init {
    main::__tests__();
}

my $START_TESTING = 0;
my $AT_END = 0;
sub notify_stopped {
    return unless $START_TESTING;

    my($self, $location) = @_;

    if ($location->subroutine =~ m/::END$/) {
        # If we're running END blocks, then we're at the end.
        # Note that the Test2 framework's END blocks run before the debugger's
        $AT_END = 1;
    }

    unless (@TEST_QUEUE) {
        my $ctx = context();
        $ctx->fail('Stopped with no tests remaining in the queue');
        $ctx->release;
        __PACKAGE__->disable_debugger();
        return;
    }
                
    TEST_QUEUE_LOOP:
    while(my $test = shift @TEST_QUEUE) {
        $test->($location);
    }

    __PACKAGE__->disable_debugger unless (@TEST_QUEUE);
}

# test-like functions

sub ok_location {
    my %params = @_;

    my $from_line = (caller)[2];

    my $test = sub {
        my $location = shift;
        my $subtest = sub {
            foreach my $key ( keys %params ) {
                is($location->$key, $params{$key}, $key);
            }
        };

        context_do {
            run_subtest("location($from_line)", $subtest);
        }
    };
    push @TEST_QUEUE, $test;
}

sub ok_at_end {
    my $from_line = (caller)[2];

    my $test = sub {
        context_do {
            my $ctx = shift;
            $ctx->ok($AT_END, "at_end($from_line)");
        };

        __PACKAGE__->disable_debugger if (! @TEST_QUEUE and $AT_END);
    };
    push @TEST_QUEUE, $test;
}

# Debugger control functions

sub db_step {
    push @TEST_QUEUE, sub {
        __PACKAGE__->step;
        no warnings 'exiting';
        last TEST_QUEUE_LOOP;
    };
}

sub db_continue {
    push @TEST_QUEUE, sub {
        __PACKAGE__->continue;
        no warnings 'exiting';
        last TEST_QUEUE_LOOP;
    }
}

sub db_stepout {
    push @TEST_QUEUE, sub {
        __PACKAGE__->stepout;
        no warnings 'exiting';
        last TEST_QUEUE_LOOP;
    }
}

__PACKAGE__->attach();

$^P = 0x73f;  # Turn on all the debugging stuff
INIT { $START_TESTING = 1 }
