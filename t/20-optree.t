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

plan tests => 0;

#subtest 'misc stuff' => sub {
#    _run_tests(
#        # lock prototype reset
#    );
#};

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
