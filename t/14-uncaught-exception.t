#!/usr/bin/env perl
use strict;
use warnings; no warnings 'void';
use lib 'lib';
use lib 't/lib';
use IO::Pipe;
use Devel::CommonDB::TestRunner;
run_in_debugger();

Devel::CommonDB::TestDB->attach();

eval { die "trapped" };
do_die();
sub do_die {
    die "untrapped"; # 15
}
exit;

package Devel::CommonDB::TestDB;
use base 'Devel::CommonDB';

sub notify_uncaught_exception {
    my($db, $exception) = @_;

    require Test::Builder;
    my $tb = Test::Builder->new();
    $tb->plan( tests => 6 );

    my %expected_location = (
        package => 'main',
        line    => 15,
        filename => __FILE__,
        subroutine => 'main::do_die'
    );

    $tb->is_eq(ref($exception), 'Devel::CommonDB::Exception', 'exception is-a Devel::CommonDB::Exception');
    foreach my $k ( keys %expected_location ) {
        $tb->is_eq($exception->$k, $expected_location{$k}, "exception location $k");
    }
    $tb->like($exception->exception, qr(untrapped), 'exception property');

    $? = 0;
}

