package Devel::CommonDB::TestRunner;

use Devel::CommonDB;
use Devel::CommonDB::Location;
use base 'Devel::CommonDB';
use Carp;

use Exporter qw(import);
our @EXPORT = qw(run_test loc run_in_debugger is_in_test_program);

sub is_in_test_program {
    no warnings 'uninitialized';
    return $ARGV[0] eq '--test';
}

my $PKG = __PACKAGE__;
our $at_end = 1;
sub run_test {
    _start_test_in_debugger() unless is_in_test_program();

    my $plan = shift;
    my $program = shift;
    my @tests = @_;

    eval "use Test::More";
    Carp::croak("Can't use Test::More: $@") if $@;
    plan(tests => $plan);


    my $db = bless \@tests, $PKG;
    $db->attach();
    {
        local($at_end) = 0;
        $program->();
    }
    $DB::single=1;

}

sub loc {
    my %params = @_;

    defined($params{subroutine}) || do { $params{subroutine} = 'ANON' };
    defined($params{filename}) || do { $params{filename} = (caller)[1] };
    defined($params{package}) || do { $params{package} = 'main' };
    return Devel::CommonDB::Location->new(%params);
}

sub notify_stopped {
    my($db, $loc) = @_;
    #printf("stopped at %s:%d\n", $loc->filename, $loc->line);

    COMMAND_LOOP:
    while( my $next_test = shift @$db ) {

        if (ref($next_test) eq 'CODE') {
            $next_test->($db, $loc);

        } elsif ($next_test->isa('Devel::CommonDB::Location')) {
            _compare_locations($db, $loc, $next_test);

        } elsif (! ref($next_test)) {
            $db->$next_test();

        } else {
            Carp::croak('Unknown test type '.ref($next_test));
        }
    }

    if (! @$db and ! $at_end) {
        ok(0, sprintf('Ran out of tests before reaching done, at %s:%d',
                        $loc->filename, $loc->line));
        exit;
    } elsif (@$db and $at_end) {
        ok(0, 'Test code ended with '.scalar(@$db).' tests remaining');
    }
}

sub notify_program_exit {
    my $db = shift;
    if (@$db) {
        ok(0, "program exit before ",scalar(@$db)," commands consumed");
    }
}

sub _compare_locations {
    my($db, $got_loc, $expected_loc) = @_;

    my @compare = (
        sub {
                my $expected_sub = $expected_loc->subroutine;
                return ($expected_sub eq 'ANON')
                        ? $got_loc->subroutine =~ m/__ANON__/
                        : $got_loc->subroutine eq $expected_sub;
            },
        sub { return $expected_loc->package eq $got_loc->package },
        sub { return $expected_loc->line == $got_loc->line },
        sub { return $expected_loc->filename eq $got_loc->filename },
    );

    my $report_test; $report_test = sub {
        Test::More::ok(shift, sprintf('Expected location %s:%d got %s:%d',
                                    $expected_loc->filename, $expected_loc->line,
                                    $got_loc->filename, $got_loc->line));
        $report_test = sub {}; # only report the error once
    };

    foreach my $compare ( @compare ) {
        unless ( $compare->() ) {
            $report_test->(0);
        }
    }
    $report_test->(1);
}
            

sub step {
    my $db = shift;
    $db->SUPER::step();
    last COMMAND_LOOP;
}

sub continue {
     my $db = shift;
    $db->SUPER::continue();
    last COMMAND_LOOP;
}

sub stepout {
    my $db = shift;
    $db->SUPER::stepout();
    last COMMAND_LOOP;
}

sub stepover {
    my $db = shift;
    $db->SUPER::stepover();
    last COMMAND_LOOP;
}

sub done {
    my $db = shift;
    $at_end = 1;
    $db->user_requested_exit();
    $db->continue;
    last COMMAND_LOOP;
}

sub at_end {
    my $db = shift;
    Test::More::ok($at_end, 'finished');
}
    


sub run_in_debugger {
    _start_test_in_debugger() unless is_in_test_program();
}

sub _start_test_in_debugger {
    my $pid = fork();
    if ($pid) {
        waitpid($pid, 0);
        Carp::croak("Child test program exited with status $?") if $?;
        exit;

    } elsif (defined $pid) {
        exec($^X, '-Ilib', '-It/lib', '-d:CommonDB::TestRunner', $0, '--test');
        Carp::croak("Exec test program failed: $!");

    } else {
        Carp::croak("Fork test program failed: $!");
    }
}

1;
