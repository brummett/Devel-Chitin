use strict;
use warnings;

use Devel::Chitin::OpTree;
use Devel::Chitin::Location;
use Test::More tests => 12;

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
                                        q(eval;),
                                        q(eval $a)),
        'block_eval' => join("\n",  q(my $a;),
                                    q(eval {),
                                    q(    $a = 1;),
                                    q(    $a),
                                    q(})),
    );
};

subtest 'string functions' => sub {
    _run_tests(
        crypt_fcn => join("\n", q(my $a;),
                                q(crypt($a, 'salt'))),
        index_fcn => join("\n", q(my $a;),
                                q($a = index($a, 'foo');),
                                q(index($a, 'foo', 1))),
        rindex_fcn  => join("\n",   q(my $a;),
                                    q($a = rindex($a, 'foo');),
                                    q(index($a, 'foo', 1))),
        substr_fcn  => join("\n",   q(my $a;),
                                    q($a = substr($a, 1, 2, 'foo');),
                                    q(substr($a, 2, 3) = 'bar')),
        sprintf_fcn => join("\n",   q(my $a;),
                                    q($a = sprintf($a, 1, 2, 3))),
        quote_qq    => join("\n",   q(my $a = 'hi there';),
                                    q(my $b = qq(Joe, $a, this is a string blah blah\n\cP\x{1f});),
                                    q($b = $a . $a;),
                                    q($b = qq($b $b))),
        pack_fcn  => join("\n", q(my $a;),
                                q($a = pack($a, 1, 2, 3))),
        unpack_fcn => join("\n",q(my $a;),
                                q($a = unpack($a);),
                                q($a = unpack('%32b', $a);),
                                q($a = unpack($a, $a))),
        reverse_fcn => join("\n",   q(my $a;),
                                    q($a = reverse(@_);),
                                    q($a = reverse($a);),
                                    q(scalar reverse(@_);),
                                    q(my @a;),
                                    q(@a = reverse(@_);),
                                    q(@a = reverse(@a))),
        tr_operator => join("\n",   q(my $a;),
                                    q($a = tr/$a/zyxw/cdsr)),
        quotemeta_fcn => join("\n", q(my $a;),
                                    q($a = quotemeta;),
                                    q($a = quotemeta $a;),
                                    q(quotemeta $a)),
        map { ( "${_}_dfl"      => $_,
                "${_}_to_var"   => join("\n",   q(my $a;),
                                                "\$a = $_"),
                "${_}_on_val"   => join("\n",   q(my $a;),
                                                "$_ \$a")
              )
            } qw( chomp chop chr hex lc lcfirst uc ucfirst length oct ord ),
    );
};

subtest regex => sub {
    _run_tests(
        anon_regex => join("\n",    q(my $a = qr/abc\w(\s+)/ims;),
                                    q(my $b = qr/abc),
                                    q(           \w),
                                    q(           $a),
                                    q(           (\s+)/iox)),
        match       => join("\n",   q(m/abc/;),
                                    q(our $a;),
                                    q($a =~ m/abc/;),
                                    q(my $rx = qr/def/;),
                                    q(my($b) = $a =~ m/abc$rx/;),
                                    q(my($c) = m/$rx def/x;),
                                    q($c = $1)),
        substitute  => join("\n",   q(s/abc/def/i;),
                                    q(my $a;),
                                    q($a =~ s/abc/def/;),
                                    q($a =~ s/abc/def$a/;),
                                    q(my $rx = qr/def/;),
                                    q(s/abd $rx/def/x;),
                                    q($a =~ s/abd $rx/def/x)),
    );
};

subtest numeric => sub {
    _run_tests(
        atan2_func => join("\n",    q(my( $a, $b );),
                                    q($a = atan2($a, $b))),
        map { ( "${_}_func" => join("\n", q(my $a;),
                                        "\$a = $_;",
                                        "\$a = $_ \$a;",
                                        "$_ \$a")
              )
            } qw(abs cos exp int log rand sin sqrt srand),
    );
};

subtest 'array functions' => sub {
    _run_tests(
        pop_fcn => join("\n",   q(my( $a, @list );),
                                q($a = pop @list;),
                                q(pop @list;),
                                q($a = pop)),
        push_fcn => join("\n",  q(my( $a, @list );),
                                q(push(@list, 1, 2, 3);),
                                q($a = push(@list, 1))),
        shift_fcn => join("\n", q(my( $a, @list );),
                                q($a = shift @list;),
                                q(shift @list;),
                                q($a = shift)),
        unshift_fcn => join("\n",   q(my( $a, @list );),
                                    q(unshift(@list, 1, 2, 3);),
                                    q($a = unshift(@list, 1))),
        splice_fcn => join("\n",q(my( $a, @list, @rv );),
                                q($a = splice(@list);),
                                q(@rv = splice(@list, 1);),
                                q(@rv = splice(@list, 1, 2);),
                                q(@rv = splice(@list, 1, 2, @rv);),
                                q(@rv = splice(@list, 1, 2, 3, 4, 5))),
        array_len => join("\n", q(my( $a, @list, $listref );),
                                q($a = $#list;),
                                q($a = $#$listref;),
                                q($a = scalar @list)),
        join_fcn => join("\n",  q(my( $a, @list );),
                                q($a = join(',', 2, 3, 4);),
                                q($a = join("\n", 2, 3, 4);),
                                q($a = join(1, @list);),
                                q(join(@list))),
    );
};

subtest 'sort/map/grep' => sub {
    _run_tests(
        map_fcn => join("\n",  q(my( $a, @list );),
                                q(map(chr, $a, $a);),
                                q(map(chr, @list);),
                                q(map { chr } ( $a, $a );),
                                q(map { chr } @list)),
        grep_fcn => join("\n",  q(my( $a, @list );),
                                q(grep(m/a/, $a, $a);),
                                q(grep(m/a/, @list);),
                                q(grep { m/a/ } ( $a, $a );),
                                q(grep { m/a/ } @list)),
        sort_fcn => join("\n",  q(my( @a, $subref, $val );),
                                q(@a = sort @a;),
                                q(@a = sort ( $val, @a );),
                                q(@a = sort { 1 } @a;),
                                q(@a = sort { ; } @a;),
                                q(@a = sort { $a <=> $b } @a;),
                                q(@a = sort { $b <=> $a } @a;),
                                q(@a = sort { $b cmp $a } @a;),
                                q(@a = reverse sort { $b cmp $a } @a;),
                                q(@a = sort scalar_assignment @a;),
                                q(@a = sort $subref @a)),
    );
};

subtest 'hash functions' => sub {
    _run_tests(
        delete_hash => join("\n",   q(our %hash;),
                                    q(my $a = delete $hash{'foo'};),
                                    q(my @a = delete @hash{'foo', 'bar'};),
                                    q(@a = delete @hash{@a};),
                                    q(delete @hash{@a};),
                                    q(delete local @hash{@a})),
        delete_array => join("\n",  q(our @array;),
                                    q(my $a = delete $array[1];),
                                    q(my @a = delete @array[1, 2];),
                                    q(@a = delete @array[@a];),
                                    q(delete local @array[@a]),),
        exists_hash => join("\n",   q(my %hash;),
                                    q(my $a = exists $hash{'foo'})),
        exists_array => join("\n",  q(my @array;),
                                    q(my $a = exists $array[1])),
        exists_sub => q(my $a = exists &scalar_assignment),
        each_fcn => join("\n",  q(my %h;),
                                q(my( $k, $v ) = each %h)),
        keys_fcn => join("\n",  q(my %h;),
                                q(my @keys = keys %h)),
        values_fcn => join("\n",q(my %h;),
                                q(my @vals = values %h)),
    );
};

subtest 'user/group info' => sub {
    _run_tests(
        getgrent_fcn => join("\n",  q(my $a = getgrent;),
                                    q($a = getgrent)),
        endhostent_fcn =>   q(endhostent),
        endnetent_fcn =>    q(endnetent),
        endpwent_fcn =>     q(endpwent),
        endgrent_fcn =>     q(endgrent),
    );

};

# test different dereferences
# @{$a->{key}->[1]}

# Tests for 5.12
# keys/values/each work on arrays

# Tests for 5.14
# keys/values/each/pop/push/shift/unshift/splice work on array/hash-refs

# Tests for 5.18
# each() assigns to $_ in a lone while test

sub _run_tests {
    my %tests = @_;
    plan tests => scalar keys %tests;

    foreach my $test_name ( keys %tests ) {
        my $code = $tests{$test_name};
        eval "sub $test_name { $code }";
        (my $expected = $code) =~ s/my(?: )?|our(?: )? //g;
        if ($@) {
            die "Couldn't compile code for $test_name: $@";
        }
        my $ops = _get_optree_for_sub_named($test_name);
        is(eval { $ops->deparse }, $expected, "code for $test_name")
            || do {
                diag("\$\@: $@\nTree:\n");
                $ops->print_as_tree
            };
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
