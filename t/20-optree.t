use strict;
use warnings;

use Devel::Chitin::OpTree;
use Devel::Chitin::Location;

use Test2::Tools::Basic;
use Test2::Tools::Compare;
use Test2::Tools::Subtest qw(subtest_buffered);
sub subtest($&);
*subtest = \&Test2::Tools::Subtest::subtest_buffered;

use Fcntl qw(:flock :DEFAULT SEEK_SET SEEK_CUR SEEK_END);
use POSIX qw(:sys_wait_h);
use Socket;
use Scalar::Util qw(blessed refaddr);

plan tests => 14;

#subtest 'misc stuff' => sub {
#    _run_tests(
#        # lock prototype reset
#    );
#};

subtest time => sub {
    _run_tests(
        localtime_fcn => join("\n", q(my $a = localtime();),
                                    q(my @a = localtime(12345))),
        gmtime_fcn => join("\n",    q(my $a = gmtime();),
                                    q(my @a = gmtime(12345))),
        time_fcn => join("\n",      q(my $a = time();),
                                    q(time())),
    );
};

subtest 'perl-5.10.1' => sub {
    _run_tests(
        requires_version(v5.10.1),
        unpack_one_arg => join("\n", q($a = unpack($a))),
        mkdir_no_args => join("\n",  q(mkdir())),
        say_fcn => join("\n",   q(my $a = say();),
                                q(say('foo bar', 'baz', "\n");),
                                q(say F ('foo bar', 'baz', "\n");),
                                q(say "Hello\n";),
                                q(say F "Hello\n";),
                                q(my $f;),
                                q(say { $f } ('foo bar', 'baz', "\n");),
                                q(say { *$f } ('foo bar', 'baz', "\n"))),
        stacked_file_tests =>   q(-r -x -d '/tmp'),
        defined_or => join("\n",q(my $a;),
                                q(my $rv = $a // 1;),
                                q($a //= 4)),
    );
};

subtest 'given-when-5.10.1' => sub {
    _run_tests(
        requires_version(v5.10.1),
        excludes_only_version(v5.27.7),
        given_when_5_10 => join("\n",
                                q(my $a;),
                                q(given ($a) {),
                               qq(\twhen (1) { print 'one' }),
                               qq(\twhen (2) {),
                               qq(\t\tprint 'two';),
                               qq(\t\tprint 'more';),
                               qq(\t\tcontinue),
                               qq(\t}),
                               qq(\twhen (3) {),
                               qq(\t\tprint 'three';),
                               qq(\t\tbreak;),
                               qq(\t\tprint 'will not run'),
                               qq(\t}),
                               qq(\tdefault { print 'something else' }),
                                q(})),
    );
};

# from the reverted given/whereso/whereis from 5.27.7
#subtest 'given-when-5.27.7' => sub {
#    _run_tests(
#        requires_version(v5.27.7),
#        given_when_5_27 => join("\n",
#                              q(my $a;),
#                              q(given ($a) {),
#                             qq(\twhereso (m/abc/) {),
#                             qq(\t\tprint 'abc';),
#                             qq(\t\tprint 'ABC'),
#                             qq(\t}),
#                             qq(\twhereso (m/def/) {),
#                             qq(\t\tprint 'def'),
#                             qq(\t}),
#                             qq(\tprint 'ghi' whereso (m/ghi/);),
#                             qq(\twhereis ('123') {),
#                             qq(\t\tprint '123'),
#                             qq(\t}),
#                             qq(\tprint '456' whereis (456);),
#                             qq(\tprint 'default case'),
#                             qq(})),
#    );
#};

subtest 'perl-5.12' => sub {
    _run_tests(
        requires_version(v5.12.0),
        keys_array => join("\n",    q(my @a = (1, 2, 3, 4);),
                                    q(keys(@a))),
        values_array => join("\n",  q(my @a = (1, 2, 3, 4);),
                                    q(values(@a))),
        each_array => join("\n",    q(my @a = (1, 2, 3, 4);),
                                    q(each(@a))),
    );
};

subtest 'perl-5.14' => sub {
    _run_tests(
        requires_version(v5.14.0),
        tr_r_flag => no_warnings('misc'),
                     join("\n",     q(my $a;),
                                    q($a = tr/$a/zyxw/cdsr)),
    );
};

subtest '5.14 experimental ref ops' => sub {
    _run_tests(
        requires_version(v5.14.0),
        excludes_version(v5.24.0),
        no_warnings(),
        keys_ref => join("\n",  q(my $h = {1 => 2, 3 => 4};),
                                q(keys($h);),
                                q(my $a = [1, 2, 3];),
                                q(keys($a))),
        each_ref => join("\n",  q(my $h = {1 => 2, 3 => 4};),
                                q(my $v = each($h);),
                                q(my $a = [1, 2, 3];),
                                q(each($a))),
        values_ref => join("\n",q(my $h = {1 => 2, 3 => 4};),
                                q(values($h);),
                                q(my $a = [1, 2, 3];),
                                q(values($a))),
        pop_ref => join("\n",   q(my $a = [1, 2, 3];),
                                q(pop($a))),
        push_ref => join("\n",  q(my $a = [1, 2, 3];),
                                q(push($a, 1))),
        shift_ref => join("\n", q(my $a = [1, 2, 3];),
                                q(shift($a))),
        unshift_ref => join("\n",   q(my $a = [1, 2, 3];),
                                    q(unshift($a, 1))),
        splice_ref => join("\n",    q(my $a = [1, 2, 3];),
                                    q(splice($a, 2, 3, 4))),
    );
};

subtest 'perl-5.16' => sub {
    _run_tests(
        requires_version(v5.16.0),
        foldcase => join("\n",  q(my $a = 'aAbBcC';),
                                q($a = fc($a);),
                                q(fc($a);),
                                q($a = fc();),
                                q(print qq(ab\F$a\E))),
    );
};

subtest 'perl-5.18' => sub {
    _run_tests(
        requires_version(v5.18.0),
        dump_expr => no_warnings('misc'),
                     join("\n", q(my $expr;),
                                q(dump $expr;),
                                q(dump 'foo' . $expr)),
        next_last_redo_expr => join("\n",   q(foreach my $a (1, 2) {),
                                           qq(\tnext \$a;),
                                           qq(\tlast 'foo' . \$a;),
                                           qq(\tredo \$a + \$a),
                                            q(})),
    );
};

subtest 'perl-5.20 incompatibilities' => sub {
    _run_tests(
        excludes_version(v5.20.0),
        do_sub =>   q(my $val = do some_sub_name(1, 2)), # deprecated sub call
    );
};

subtest 'perl-5.20' => sub {
    _run_tests(
        requires_version(v5.20.0),
        hash_slice_hash => join("\n",   q(my(%h, $h);),
                                        q(my %slice = %h{'key1', 'key2'};),
                                        q(%slice = %$h{'key1', 'key2'})),
        hash_slice_array=> join("\n",   q(my(@a, $a);),
                                        q(my %slice = %a[1, 2];),
                                        q(%slice = %$a[1, 2])),
        # although there's no way to distinguish @$a from $a->@*, it checks whether
        # the "postderef" feature is on and uses it if it is
        # commented out for now because it messed with the two slice tests above
#        postderef => join("\n",         q(my $a = 1;),
#                                        q(our $b = 2;),
#                                        q($a->[1]->$*;),
#                                        q($a->{'one'}->@*;),
#                                        q($b->[1]->$#*;),
#                                        q($b->{'one'}->%*;),
#                                        q($a->[1]->&*;),
#                                        q($a->[1]->**;)),
# postfix dereferencing
# $a->@*
# $a->@[1,2]
# $a->%{'one', 'two'}
# check warning bits for "use experimental 'postderef'
    );
};

subtest 'perl-5.22 differences' => sub {
    _run_tests(
        excludes_version(v5.22.0),
        readline_with_brackets => join("\n",    q(my $fh;),
                                                q(my $line = <$fh>;),
                                                q(my @lines = <$fh>)),
        hash_key_assignment => join("\n",   q(my(%a, $a);),
                                            q($a{key} = 1;),
                                            q($a{'key'} = 1;),
                                            q($a{'1'} = 1;),
                                            q($a->{key} = 1;),
                                            q($a->{'key'} = 1;),
                                            q($a->{'1'} = 1)),
    );
};

subtest 'perl-5.22' => sub {
    _run_tests(
        requires_version(v5.22.0),
        use_feature('bitwise'),
        use_feature('refaliasing'),
        string_bitwise  => join("\n",   q(my($a, $b);),
                                        q($a = $a &. $b;),
                                        q($a &.= $b;),
                                        q($a = $a |. 'str';),
                                        q($a |.= 'str';),
                                        q($a = $a ^. 1;),
                                        q($a ^.= $b;),
                                        q($a = ~.$a)),
        regex_n_flag => join("\n",  q(my $str;),
                                    q($str =~ m/(hi|hello)/n)),
        list_repeat => join("\n",   q(my @a = (1, 2) x 5)),
        ref_alias => join("\n",     q(my($a, $b) = (1, 2);),
                                    q(\$a = \$b;),
                                    q[\($a) = \$b;],
                                    q(our @array = (1, 2);),
                                    q(\$array[1] = \$a;),
                                    q(my %hash = (1, 1);),
                                    q(\$hash{'1'} = \$b)),
        listref_alias => join("\n", q(my($a, $b, @array);),
                                    q(\@array[1, 2] = (\$a, \$b);),
                                    q[\(@array) = (\$a, \$b)]),
        alias_whole_array => join("\n", q(my @array = (1, 2);),
                                        q(our @ar2 = (1, 2);),
                                        q[\(@array) = \(@ar2);],
                                        q[\(@ar2) = \(@array)]),
        double_diamond => join("\n",    q(while (defined($_ = <<>>)) {),
                                       qq(\tprint()),
                                        q(})),
    );
};

subtest 'perl-5.25.6 split changes' => sub {
    _run_tests(
        excludes_version(v5.25.6),
        split_specials => join("\n",    q(our @s = split('', $a);),
                                        q(my @strings = split(' ', $a))),
    );
};

subtest 'perl-5.28.0' => sub {
    _run_tests(
        requires_version(v5.28.0),
        delete_hash_slice => join("\n", q(my %myhash;),
                                        q(my %a = delete(%myhash{'baz', 'quux'}))),
    );
};

sub requires_version {
    my $ver = shift;
    Devel::Chitin::RequireVersion->new($ver);
}

sub use_feature {
    my $f = shift;
    Devel::Chitin::UseFeature->new($f);
}

sub excludes_version {
    my $ver = shift;
    Devel::Chitin::ExcludeVersion->new($ver);
}

sub excludes_only_version {
    my $ver = shift;
    Devel::Chitin::ExcludeOnlyVersion->new($ver);
}

sub no_warnings {
    my $warn = shift;
    Devel::Chitin::NoWarnings->new($warn);
}

sub _run_tests {
    my @tests = @_;

    my $testwide_preamble = '';
    while (@tests and blessed($tests[0])) {
        my $obj = shift @tests;
        my $directive = $obj->compose();
        if (defined $directive) {
            $testwide_preamble .= $directive;
        } else {
            return ();
        }
    }

    plan tests => _count_tests(@tests);

    while (@tests) {
        my $test_name = shift @tests;

        my $preamble = '';
        while (blessed $tests[0]) {
            $preamble .= shift(@tests)->compose;
        }
        my $code = shift @tests;
        my $eval_string = "${testwide_preamble}${preamble}sub $test_name { $code }";
        my $exception = do {
            local $@;
            eval $eval_string;
            $@;
        };
        if ($exception) {
            die "Couldn't compile code for $test_name: $exception\nCode was:\n$eval_string";
        }
        (my $expected = $code) =~ s/\b(?:my|our)\b\s*//mg;
        my $ops = _get_optree_for_sub_named($test_name);
        my $got = eval { $ops->deparse };
        is($got, $expected, "code for $test_name")
            || do {
                diag("showing whitespace:\n>>".join("<<\n>>", split("\n", $got))."<<");
                diag("\$\@: $@\nTree:\n");
                $ops->print_as_tree
            };
    }
}

sub _count_tests {
    my @tests = @_;
    my $count = 0;
    for (my $i = 0; $i < @tests; $i++) {
        next if ref($tests[$i]);
        $count++;
    }
    return int($count / 2);
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

package
    Devel::Chitin::TestDirective;
sub new {
    my($class, $code) = @_;
    return bless \$code, $class;
}

package
    Devel::Chitin::RequireVersion;
use base 'Devel::Chitin::TestDirective';
use Test::More;

sub compose {
    my $self = shift;
    my $required_version_string = sprintf('%vd', $$self);
    if ($^V lt $$self) {
        plan skip_all => "needs version $required_version_string";
        return undef;
    }

    my $preamble = "use $required_version_string;";
    if ($^V ge v5.18.0) {
        $preamble .= "\nno warnings 'experimental';";
    }
    return $preamble;
}

package
    Devel::Chitin::ExcludeVersion;
use base 'Devel::Chitin::TestDirective';
use Test::More;

sub compose {
    my $self = shift;
    my $excluded_version_string = sprintf('%vd', $$self);
    if ($^V ge $$self) {
        plan skip_all => "doesn't work starting with version $excluded_version_string";
        return undef;
    }
    return '';
}

package
    Devel::Chitin::ExcludeOnlyVersion;
use base 'Devel::Chitin::TestDirective';
use Test::More;

sub compose {
    my $self = shift;
    my $excluded_version_string = sprintf('%vd', $$self);
    if ($^V eq $$self) {
        plan skip_all => "doesn't work with version $excluded_version_string";
        return undef;
    }
    return '';
}

package
    Devel::Chitin::UseFeature;
use base 'Devel::Chitin::TestDirective';
sub compose {
    my $self = shift;
    sprintf(q(use feature '%s';), $$self);
}

package
    Devel::Chitin::NoWarnings;
use base 'Devel::Chitin::TestDirective';
sub compose {
    my $self = shift;
    $$self ? sprintf(q(no warnings '%s';), $$self) : 'no warnings;';
}
