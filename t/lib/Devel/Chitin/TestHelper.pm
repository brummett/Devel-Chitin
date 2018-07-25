package Devel::Chitin::TestHelper;

use strict;
use warnings;

use Test2::V0;
use Test2::API qw( context_do context run_subtest test2_add_callback_testing_done);
use base 'Devel::Chitin';
use Carp;

use Exporter 'import';
our @EXPORT_OK = qw(ok_location ok_breakable ok_not_breakable ok_trace_location
                    ok_set_breakpoint ok_breakpoint ok_change_breakpoint ok_delete_breakpoint
                    ok_set_action
                    ok_at_end
                    do_test do_disable_auto_disable
                    db_step db_continue db_stepout db_stepover db_trace db_disable
                    has_callsite
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

sub guard(&) {
    my $code = shift;
    bless $code, 'Devel::Chitin::TestHelper::Guard';
}
sub Devel::Chitin::TestHelper::Guard::DESTROY {
    my $code = shift;
    $code->();
}

my $START_TESTING = 0;
my $AT_END = 0;
my $IS_STOPPED = 0;
my $CONTINUE_AFTER_TEST_QUEUE_IS_EMPTY = 0;
sub notify_stopped {
    return unless $START_TESTING;

    my $guard = guard { $IS_STOPPED = 0 };
    $IS_STOPPED = 1;

    my($self, $location) = @_;

    if ($location->subroutine =~ m/::END$/) {
        # If we're running END blocks, then we're at the end.
        # Note that the Test2 framework's END blocks run before the debugger's
        $AT_END = 1;
    }

    unless (@TEST_QUEUE) {
        my $ctx = context();
        $ctx->fail(sprintf('Stopped at %s:%d with no tests remaining in the queue', $location->filename, $location->line));
        $ctx->release;
        __PACKAGE__->disable_debugger();
        return;
    }

    TEST_QUEUE_LOOP:
    while(my $test = shift @TEST_QUEUE) {
        $test->($location);
    }

    __PACKAGE__->disable_debugger unless (@TEST_QUEUE or $CONTINUE_AFTER_TEST_QUEUE_IS_EMPTY);
}

my $IS_TRACE = 0;
sub notify_trace {
    my($self, $location) = @_;

    my $guard = guard { $IS_TRACE = 0 };
    $IS_TRACE=1;

    unless (@TEST_QUEUE) {
        my $ctx = context();
        $ctx->fail(sprintf('notify_trace() at %s:%d with no trace tests remaining in the queue', $location->filename, $location->line));
        $ctx->release;
        __PACKAGE__->disable_debugger();
        return;
    }

    my $test = shift @TEST_QUEUE;
    $test->($location);

    __PACKAGE__->disable_debugger unless (@TEST_QUEUE);
}

# test-like functions

sub _test_location {
    my($check_flag_ref, $check_flag_label, %params) = @_;

    my $from_line = (caller(1))[2];

    my $test = sub {
        my $location = shift;
        my $subtest = sub {
            unless ($$check_flag_ref) {
                fail("Checking location when debugger is not $check_flag_label");
                return;
            }
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

sub ok_location {
    _test_location(\$IS_STOPPED, 'stopped', @_);
}

sub ok_trace_location {
    _test_location(\$IS_TRACE, 'traced', @_);
}

sub ok_breakpoint {
    my %params = @_;

    my($file, $from_line) = (caller)[1, 2];
    $params{file} = $file unless exists ($params{file});
    my $bp_line = $params{line};

    my $subtest = sub {
        my @bp = Devel::Chitin::Breakpoint->get(%params);
        if (@bp != 1) {
            fail("Expected 1 breakpoint in ok_breakpoint($from_line), but got ".scalar(@bp));
        }

        ok($bp[0], 'Got breakpoint');
        foreach my $attr ( keys %params ) {
            is($bp[0]->$attr, $params{$attr}, $attr);
        }
    };
    push @TEST_QUEUE, sub {
        context_do {
            run_subtest("breakpoint($from_line) ${file}:${bp_line}", $subtest);
        }
    };
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

sub ok_breakable {
    my($file, $line) = @_;
    my $from_line = (caller)[2];

    my $test = sub {
        context_do {
            my $ctx = shift;
            $ctx->ok( __PACKAGE__->is_breakable($file, $line), "${file}:${line} is breakable");
        };
    };
    push @TEST_QUEUE, $test;
}

sub ok_not_breakable {
    my($file, $line) = @_;

    my $test = sub {
        context_do {
            my $ctx = shift;
            $ctx->ok( ! __PACKAGE__->is_breakable($file, $line), "${file}:${line} is not breakable");
        };
    };
    push @TEST_QUEUE, $test;
}

sub ok_set_action {
    my $comment = pop;
    my %params = @_;

    $params{file} = (caller)[1] unless exists $params{file};

    my $test = sub {
        context_do {
            my $ctx = shift;
            $ctx->ok( Devel::Chitin::Action->new(%params), $comment);
        };
    };
    push @TEST_QUEUE, $test;
}

sub ok_set_breakpoint {
    my $comment = pop;
    my %params = @_;

    $params{file} = (caller)[1] unless exists $params{file};

    my $test = sub {
        context_do {
            my $ctx = shift;
            $ctx->ok( Devel::Chitin::Breakpoint->new(%params), $comment);
        };
    };
    push @TEST_QUEUE, $test;
}

sub ok_change_breakpoint {
    my $comment = pop;
    my %params = @_;

    my $changes = delete $params{change};
    unless (ref($changes) eq 'HASH') {
        Carp::croak("'change' is a required param to ok_change_breakpoint(), and must be a hashref");
    }

    my $test = sub {
        context_do {
            my $ctx = shift;

            my @bp = Devel::Chitin::Breakpoint->get(%params);
            unless (@bp) {
                $ctx->fail('params matched no breakpoints: ', join(', ', map { "$_ => ".$params{$_} } keys(%params)));
            }
            foreach my $bp ( @bp ) {
                foreach my $param (keys %$changes) {
                    $bp->$param($changes->{$param});
                }
                $ctx->pass(sprintf('%s at %s:%d', $comment, $bp->file, $bp->line));
            }
        };
    };
    push @TEST_QUEUE, $test;
}

sub ok_delete_breakpoint {
    my $comment = pop;
    my %params = @_;

    my $test = sub {
        context_do {
            my $ctx = shift;

            my @bp = Devel::Chitin::Breakpoint->get(%params);
            foreach my $bp ( @bp ) {
                $ctx->ok($bp->delete, sprintf('Delete breakpoint at %s:%d', $bp->file, $bp->line));
            }
        };
    };
    push @TEST_QUEUE, $test;
}

sub do_test(&) {
    push @TEST_QUEUE, shift();
}

sub do_disable_auto_disable {
    push @TEST_QUEUE, sub {
        $CONTINUE_AFTER_TEST_QUEUE_IS_EMPTY = 1;
    }
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

sub db_stepover {
    push @TEST_QUEUE, sub {
        __PACKAGE__->stepover;
        no warnings 'exiting';
        last TEST_QUEUE_LOOP;
    }
}

sub db_trace {
    my $val = shift;
    push @TEST_QUEUE, sub {
        __PACKAGE__->trace($val);
    }
}

sub db_disable {
    push @TEST_QUEUE, sub {
        __PACKAGE__->disable_debugger;
    }
}

my $has_callsite;
sub has_callsite {
    unless (defined $has_callsite) {
        my $test_callsite = ( sub { Devel::Chitin::Location::get_callsite(0) })->();
        $has_callsite = !! $test_callsite;
    }
    $has_callsite;
}

__PACKAGE__->attach();

$^P = 0x73f;  # Turn on all the debugging stuff
INIT { $START_TESTING = 1 }
