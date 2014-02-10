#!/usr/bin/env perl
use strict;
use warnings; no warnings 'void';
use lib 'lib';
use lib 't/lib';
use Devel::CommonDB::TestRunner;
run_in_debugger();

setup_breakpoints_and_actions();
Devel::CommonDB::TestDB1->attach();
Devel::CommonDB::TestDB2->attach();

13;

BEGIN {
    @main::expected = qw(
        Devel::CommonDB::TestDB1::init
        Devel::CommonDB::TestDB2::init
        action
        breakpoint
        Devel::CommonDB::TestDB1::notify_stopped
        Devel::CommonDB::TestDB2::notify_stopped
        Devel::CommonDB::TestDB1::poll
        Devel::CommonDB::TestDB2::poll
        Devel::CommonDB::TestDB1::idle
        Devel::CommonDB::TestDB2::idle
        Devel::CommonDB::TestDB1::notify_resumed
        Devel::CommonDB::TestDB2::notify_resumed
    );
    if (Devel::CommonDB::TestRunner::is_in_test_program) {
        eval 'use Test::More tests => scalar(@main::expected)';
    }
}

sub setup_breakpoints_and_actions {
    Devel::CommonDB::Action->new(
        file => __FILE__,
        line => 13,
        code => q( Test::More::is(shift(@main::expected), 'action', 'action fired') ));
    Devel::CommonDB::Breakpoint->new(
        file => __FILE__,
        line => 13,
        code => q( Test::More::is(shift(@main::expected), 'breakpoint', 'Breakpoint fired'); 1) );
    Devel::CommonDB->user_requested_exit();
}
        

package Devel::CommonDB::CommonParent;
use base 'Devel::CommonDB';

BEGIN {
    foreach my $subname ( qw( init notify_stopped poll idle notify_resumed ) ) {
        my $sub = sub {
            my($class, $loc) = @_;

            my $next_test = shift @main::expected;
            unless ($next_test) {
                Test::More::ok(0, sprintf('%s::%s ran out if tests at %s:%d',
                                        $class, $subname, $loc->filename, $loc->line));
                exit;
            }
            my($got_class, $got_subname) = ($next_test =~ m/^(.*)::(\w+)/);
            my $ok = $got_class eq $class
                    and
                    $got_subname eq $subname;
            Test::More::ok($ok, "${got_class}::${got_subname} eq ${class}::${subname}");
            return 1;
        };
        no strict 'refs';
        *$subname = $sub;
    }
}
                
package Devel::CommonDB::TestDB1;
use base 'Devel::CommonDB::CommonParent';

package Devel::CommonDB::TestDB2;
use base 'Devel::CommonDB::CommonParent';

