use Test2::V0;

# When this test is run with no args, it runs all tests if finds under
# a subdirectory of the name of this test.  You can also run one or more
# tests by putting them on the command line

use Devel::Chitin::OpTree;
use Devel::Chitin::Location;
use IO::File;

my @tests = plan_tests(@ARGV);
plan tests => scalar(@tests);
$_->() foreach @tests;

sub plan_tests {
    if (@_) {
        map { make_specific_test($_) } @_;
    } else {
        make_all_tests();
    }
}

sub make_specific_test {
    my $file = shift;
    return sub { run_one_test( $file ) };
}

sub make_all_tests {
    my($dir) = (__FILE__ =~ m/(.*?)\.t$/);
    my @subdirs = _contents_under_dir($dir);
    map { make_subdir_test($_) } @subdirs;
}

sub make_subdir_test {
    my $subdir = shift;
    sub {
        my @tests = _contents_under_dir($subdir);
        subtest $subdir => sub {
            plan tests => scalar(@tests);

            run_one_test($_) foreach @tests;
        };
    };
}

sub _contents_under_dir {
    my $dir = shift;
    grep { ! m/^\./ } glob("${dir}/*");
}

sub run_one_test {
    my $file = shift;

    my $fh = IO::File->new($file) || die "Can't open $file: $!";
    my $test_code = do {
        local $/;
        <$fh>;
    };
    $fh->close;

    (my $subname = $file) =~ s#/|-|\.#_#g;
    my $test_as_sub = sprintf('sub %s { %s }', $subname, $test_code);
    my $exception = do {
        local $@;
        eval $test_as_sub;
        $@;
    };
    if ($exception) {
        die "Couldn't compile code for $file: $exception";
    }

    (my $expected = $test_code) =~ s/\b(?:my|our)\b\s*//mg;
    $expected =~ s/#.*?\n//g;  # remove comments

    my $ops = _get_optree_for_sub_named($subname);
    my $got = eval { $ops->deparse };
    is("$got\n", $expected, $file)
        || do {
            diag("Showing whitespace:\n>>" . join("<<\n>>", split("\n", $got)) . "<<");
            diag('$@: ' . $@ . "\nTree:\n");
            $ops->print_as_tree;
        };
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

