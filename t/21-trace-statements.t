#!/usr/bin/env perl
use strict;
use warnings; no warnings 'void';
use lib 'lib';
use lib 't/lib';
use Devel::Chitin::TestRunner;
run_in_debugger();

Devel::Chitin::TestDB->attach();
Devel::Chitin::TestDB->trace(1);

my $line = 12;
my $i = 0; my $b = 13;
while ($i < 2) {
    foo($i);
} continue {
    my $a = $i++;
}
$line = 19;
sub foo {
    $line = 21;
}

BEGIN {
    if (is_in_test_program) {
        if (Devel::Chitin::TestRunner::has_callsite) {
            eval "use Test::More tests => 22;";
        } else {
            eval "use Test::More skip_all => 'Devel::Callsite is not available'";
        }
    }
}

package Devel::Chitin::TestDB;
use base 'Devel::Chitin';
my @trace;
BEGIN {
    @trace = (
        '$line = 12',
        '$i = 0',
        '$b = 13',
        # while loop
        join("\n",  'while ($i < 2) {',
                    "\tfoo(\$i)",
                    '} continue {',
                    "\t\$a = \$i++",
                    '}'),
        # about to call foo()
        'foo($i)',
        '$line = 21',
        # continue
        '$a = $i++',
        # About to call foo() again
        'foo($i)',
        '$line = 21',
        # continue
        '$a = $i++',
        # done
        '$line = 19',
    );
}

sub notify_trace {
    my($class, $loc) = @_;

    my $expected_next_statement = shift @trace;
    exit unless $expected_next_statement;

    my $next_statement = $class->next_statement();
    Test::More::is($next_statement, $expected_next_statement, 'next_statement for line '.$loc->line)
        || do {
            Test::More::diag(sprintf("stopped at line %d callsite 0x%0x\n", $loc->line, $loc->callsite));
            Test::More::diag(Devel::Chitin::OpTree->build_from_location($loc)->print_as_tree($loc->callsite));
        };

    eval { $class->next_statement(1) };
    Test::More::ok(! $@, 'able to get next_statement on parent for line '.$loc->line)
        || Test::More::diag("exception was: $@");
}

