use strict;
use warnings;

use Devel::Chitin::OpTree;
use Devel::Chitin::Location;
use Test::More tests => 5;

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
    _run_tests(
        list_assignment => join("\n", q(my @a = ( 1, 2 );),
                                      q(our @b = ( 3, 4 );),
                                      q(@a = @b;),
                                      q(@a = ( @b, @a )),
            ),
        list_index_assignment => join("\n", q(my @the_list;),
                                            q(my $idx;),
                                            q($the_list[2] = 'foo';),
                                            q($the_list[$idx] = 'bar')),

        list_slice_assignment => join("\n", q(my @the_list;),
                                            q(my $idx;),
                                            q(my @other_list;),
                                            q(@the_list[1, $idx, 3, @other_list] = @other_list[1, 2, 3])),
        # These hash assigments are done with aassign, so there's no way to
        # tell that the lists would look better as ( one => 1, two => 2 )
        hash_assignment => join("\n",   q(my %a = ( 'one', 1, 'two', 2 );),
                                        q(our %b = ( 'three', 3, 'four', 4 );),
                                        q(%a = %b;),
                                        q(%a = ( %b, %a ))),
        hash_slice_assignment => join("\n", q(my %the_hash;),
                                            q(my @indexes;),
                                            q(@the_hash{'1', 'key', @indexes} = ( 1, 2, 3 ))),

        scalar_ref_assignment => join("\n", q(my $a = 1;),
                                            q(our $b = \$a;),
                                            q($$b = 2)),

        array_ref_assignment => join("\n",  q(my $a = [ 1, 2 ];),
                                            q(@$a = ( 1, 2 ))),
        array_ref_slice_assignment => join("\n",    q(my $list;),
                                                    q(my $other_list;),
                                                    q(@$list[1, @$other_list] = ( 1, 2, 3 ))),

        hash_ref_assignment => join("\n",   q(my $a = { 1 => 1, two => 2 };),
                                            q(%$a = ( 'one', 1, 'two', 2 ))),
        hasf_ref_slice_assignment => join("\n", q(my $hash = {  };),
                                                q(my @list;),
                                                q(@$hash{'one', @list, 'last'} = @list)),
    );
};

subtest 'conditional' => sub {
    _run_tests(
        'num_lt' => join("\n",  q(my $a = 1;),
                                q(my $result = $a < 5)),
        'num_gt' => join("\n",  q(my $a = 1;),
                                q(my $result = $a > 5)),
        'num_eq' => join("\n",  q(my $a = 1;),
                                q(my $result = $a == 5)),
        'num_le' => join("\n",  q(my $a = 1;),
                                q(my $result = $a <= 5)),
        'num_cmp' => join("\n", q(my $a = 1;),
                                q(my $result = $a <=> 5)),
        'num_ge' => join("\n",  q(my $a = 1;),
                                q(my $result = $a >= 5)),
        'str_lt' => join("\n",  q(my $a = 'one';),
                                q(my $result = $a lt 'five')),
        'str_gt' => join("\n",  q(my $a = 'one';),
                                q(my $result = $a gt 'five')),
        'str_eq' => join("\n",  q(my $a = 'one';),
                                q(my $result = $a eq 'five')),
        'str_le' => join("\n",  q(my $a = 'one';),
                                q(my $result = $a le 'five')),
        'str_ge' => join("\n",  q(my $a = 'one';),
                                q(my $result = $a ge 'five')),
        'str_cmp' => join("\n", q(my $a = 1;),
                                q(my $result = $a cmp 5)),
    );
};

subtest 'subroutine call' => sub {
    _run_tests(
        'call_sub' => join("\n",    q(foo( 1, 2, 3 ))),
        'call_subref' => join("\n", q(my $a;),
                                    q($a->( 1, 'two', 3 ))),
        'call_subref_from_array' => join("\n",  q(my @a;),
                                                q($a[0]->( 1, 'two', 3 ))),
        'call_sub_from_package' => q(Some::Other::Package::foo( 1, 2, 3 )),
        'call_class_method_from_package' => q(Some::Other::Package->foo( 1, 2, 3 )),
        'call_instance_method' => join("\n",    q(my $obj;),
                                                q($obj->foo( 1, 2, 3 ))),
        'call_instance_variable_method' => join("\n",   q(my $obj;),
                                                        q(my $method;),
                                                        q($obj->$method( 1, 2, 3 ))),
        'call_class_variable_method' => join("\n",  q(my $method;),
                                                    q(Some::Other::Package->$method( 1, 2, 3 ))),
    );
};

subtest 'eval' => sub {
    _run_tests(
        'const_string_eval' => q(eval 'this is a string'),
        'var_string_eval' => join("\n", q(my $a;),
                                        q(eval $a)),
        'block_eval' => join("\n",  q(my $a;),
                                    q(eval {),
                                    q(    $a = 1;),
                                    q(    $a),
                                    q(})),
    );
};

sub _run_tests {
    my %tests = @_;
    plan tests => scalar keys %tests;

    foreach my $test_name ( keys %tests ) {
        my $code = $tests{$test_name};
        eval "sub $test_name { $code }";
        (my $expected = $code) =~ s/my |our //g;
        if ($@) {
            die "Couldn't compile code for $test_name: $@";
        }
        my $ops = _get_optree_for_sub_named($test_name);
        is($ops->deparse, $expected, "code for $test_name");
    }
}


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
