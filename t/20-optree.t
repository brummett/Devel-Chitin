use strict;
use warnings;

use Devel::Chitin::OpTree;
use Devel::Chitin::Location;
use Test::More tests => 2;

subtest construction => sub {
    plan tests => 4;

    sub scalar_assignment {
        my $a = 1;
    }

    my $ops = _get_optree_for_sub_named('scalar_assignment');
    ok($ops, 'create optree');
    my $count = 0;
    $ops->walk_inorder(sub { $count++ });
    ok($count > 1, 'More than one op is part of scalar_assignment');

    is($ops->deparse, '$a = 1', 'scalar_assignment');

    sub multi_statement_scalar_assignment {
        my $a = 1;
        my $b = 2;
    }
    is(_get_optree_for_sub_named('multi_statement_scalar_assignment')->deparse,
        join("\n", q($a = 1;), q($b = 2)),
        'multi_statement_scalar_assignment');
};

subtest 'assignment' => sub {
    my %tests = (
        scalar_ref_assignment => join("\n", q(my $a = 1;),
                                            q(my $b = \$a;),
                                            q($$b = 2)),
    );
    plan tests => scalar keys %tests;

    foreach my $test_name ( keys %tests ) {
        my $code = $tests{$test_name};
        eval "sub $test_name { $code }";
        (my $expected = $code) =~ s/my //g;
        if ($@) {
            die "Couldn't compile code for $test_name: $@";
        }
        my $ops = _get_optree_for_sub_named($test_name);
        is($ops->deparse, $expected, "code for $test_name");
    }
};


sub _get_optree_for_sub_named {
    my $subname = shift;
    Devel::Chitin::OpTree->build_from_location(
        Devel::Chitin::Location->new(
            package => 'main',
            subroutine => $subname,
            filename => __FILE__,
            line => 1,
        )
    );
}
