package Devel::Chitin::OpTree;

use strict;
use warnings;

use Carp;
use Scalar::Util qw(blessed);
use B;

use Devel::Chitin::OpTree::UNOP;
use Devel::Chitin::OpTree::SVOP;
use Devel::Chitin::OpTree::PADOP;
use Devel::Chitin::OpTree::COP;
use Devel::Chitin::OpTree::PVOP;
use Devel::Chitin::OpTree::METHOP;
use Devel::Chitin::OpTree::BINOP;
use Devel::Chitin::OpTree::LOGOP;
use Devel::Chitin::OpTree::LOGOP_AUX;
use Devel::Chitin::OpTree::LISTOP;
use Devel::Chitin::OpTree::LOOP;
use Devel::Chitin::OpTree::PMOP;

sub build_from_location {
    my($class, $start) = @_;

    my $start_op = _get_starting_op_of($start);

    # adapted from B::walkoptree_slow
    my @parents;
    my $build_walker;
    $build_walker = sub {
        my $op = shift;
        my @children;
        if ($$op && ($op->flags & B::OPf_KIDS)) {
            unshift(@parents, $op);
            for (my $kid_op = $op->first; $$kid_op; $kid_op = $kid_op->sibling) {
                push @children, $build_walker->($kid_op);
            }
            shift(@parents);
        }

        if (B::class($op) eq 'PMOP'
            and ref($op->pmreplroot)
            and ${$op->pmreplroot}
            and $op->plreplroot->isa('B::OP')
        ) {
            unshift @parents, $op;
            push @children, $build_walker->($op->plreplroot);
            shift @parents;
        }

        return $class->new(
                    op => $op,
                    parent => $parents[0],
                    children => \@children,
                );
    };

    $build_walker->($start_op);
}

sub _get_starting_op_of {
    my $start = shift;

    unless (blessed($start) and $start->isa('Devel::Chitin::Location')) {
        Carp::croak('build_from_location() requires a Devel::Chitin::Location as an argument');
    }

    if ($start->package eq 'main' and $start->subroutine eq 'MAIN') {
        return B::main_root();

    } elsif ($start->subroutine =~ m/::__ANON__\[\S+:\d+\]/) {
        Carp::croak(q(Don't know how to handle anonymous subs yet));

    } else {
        my $subname = join('::', $start->package, $start->subroutine);
        my $subref = do { no strict 'refs'; \&$subname };
        my $cv = B::svref_2object($subref);
        return $cv->ROOT;
    }
}

sub new {
    my($class, %params) = @_;
    unless (exists $params{op}
            and exists $params{parent}
            and exists $params{children}
    ) {
        Carp::croak(q{'op', 'parent' and 'children' are all required parameters of new()});
    }

    my $final_class = _class_for_op($params{op});

    my $self = bless \%params, $final_class;
    $self->_build();
    return $self;
}

sub _class_for_op {
    my $op = shift;
    my $b_class = B::class($op);
    if ($b_class eq 'OP') {
        return __PACKAGE__,
    } else {
        join('::', __PACKAGE__, B::class($op));
    }
}

sub _build { }

sub op { shift->{op} }
sub parent { shift->{parent} }
sub children { shift->{children} }

sub walk_preorder {
    my($self, $cb) = @_;
    $_->walk_preorder($cb) foreach (@{ $self->children });
    $cb->($self);
}

sub walk_inorder {
    my($self, $cb) = @_;
    $cb->($self);
    $_->walk_inorder($cb) foreach (@{ $self->children } );
}

1;
