package Devel::Chitin::OpTree;

use strict;
use warnings;

use Devel::Chitin::Version;

use Carp;
use Scalar::Util qw(blessed);
use B qw(ppname);

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

    my($start_op, $cv) = _determine_start_of($start);

    # adapted from B::walkoptree_slow
    my @parents;
    my $build_walker;
    $build_walker = sub {
        my $op = shift;

        my $self = $class->new(op => $op, cv => $cv);

        my @children;
        if ($$op && ($op->flags & B::OPf_KIDS)) {
            unshift(@parents, $self);
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
            unshift @parents, $self;
            push @children, $build_walker->($op->plreplroot);
            shift @parents;
        }

        @$self{'parent','children'} = ($parents[0], \@children);
        $self;
    };

    $build_walker->($start_op);
}

sub _determine_start_of {
    my $start = shift;

    unless (blessed($start) and $start->isa('Devel::Chitin::Location')) {
        Carp::croak('build_from_location() requires a Devel::Chitin::Location as an argument');
    }

    if ($start->package eq 'main' and $start->subroutine eq 'MAIN') {
        return (B::main_root(), B::main_cv);

    } elsif ($start->subroutine =~ m/::__ANON__\[\S+:\d+\]/) {
        Carp::croak(q(Don't know how to handle anonymous subs yet));

    } else {
        my $subname = join('::', $start->package, $start->subroutine);
        my $subref = do { no strict 'refs'; \&$subname };
        my $cv = B::svref_2object($subref);
        return ($cv->ROOT, $cv);
    }
}

sub new {
    my($class, %params) = @_;
    unless (exists $params{op}) {
        Carp::croak(q{'op' is a required parameter of new()});
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
    } elsif ($b_class eq 'UNOP'
             and $op->name eq 'null'
             and $op->flags & B::OPf_KIDS
    ) {
        my $num_children = 0;
        for (my $kid_op = $op->first; $$kid_op; $kid_op = $kid_op->sibling) {
            $num_children++ ;
        }
        if ($num_children > 2) {
            return join('::', __PACKAGE__, 'LISTOP');
        } elsif ($num_children > 1) {
            return join('::', __PACKAGE__, 'BINOP');

        } else {
            return join('::', __PACKAGE__, 'UNOP');
        }
    } else {
        join('::', __PACKAGE__, B::class($op));
    }
}

sub _build { }

sub op { shift->{op} }
sub parent { shift->{parent} }
sub children { shift->{children} }
sub cv { shift->{cv} }

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

sub deparse {
    my $self = shift;
    my $bounce = 'pp_' . $self->op->name;
    $self->$bounce();
}

sub _deparsed_children {
    my $self = shift;
    return grep { $_ }
           map { $_->deparse }
           @{ $self->children };
}

sub is_null {
    return shift->op->name eq 'null';
}

sub pp_null {
    my $self = shift;
    my $bounce = $self->_ex_name;
    $self->$bounce(@_);
}

sub pp_padsv {
    my $self = shift;
    # These are 'my' variables.  We're omitting the 'my' because
    # that happens at compile time
    $self->_padname_sv->PV;
}
*pp_padav = \&pp_padsv;
*pp_padhv = \&pp_padsv;

sub pp_aelemfast_lex {
    my $self = shift;
    my $list_name = substr($self->pp_padav, 1); # remove the sigil
    "\$${list_name}[" . $self->op->private . ']';
}

sub pp_padrange {
    my $self = shift;
    # These are 'my' variables.  We're omitting the 'my' because
    # that happens at compile time
    $self->_padname_sv->PV;
}

sub pp_pushmark {
    my $self = shift;

    '(';
}

sub _padname_sv {
    my $self = shift;
#    print "in padname_sv\n";
#    print "PADLIST: ",$self->cv->PADLIST,"\n";
#    print "ARRAYelt(0): ",$self->cv->PADLIST->ARRAYelt(0),"\n";
    return $self->cv->PADLIST->ARRAYelt(0)->ARRAYelt( $self->op->targ );
}

sub _ex_name {
    my $self = shift;
    if ($self->op->name eq 'null') {
        ppname($self->op->targ);
    }
}

my %flag_values = (
    WANT_VOID => B::OPf_WANT_VOID,
    WANT_SCALAR => B::OPf_WANT_SCALAR,
    WANT_LIST => B::OPf_WANT_LIST,
    KIDS => B::OPf_KIDS,
    PARENS => B::OPf_PARENS,
    REF => B::OPf_REF,
    MOD => B::OPf_MOD,
    STACKED => B::OPf_STACKED,
    SPECIAL => B::OPf_SPECIAL,
);
sub print_as_tree {
    my $self = shift;
    $self->walk_inorder(sub {
        my $op = shift;
        my($level, $parent) = (0, $op);
        $level++ while($parent = $parent->parent);
        my $name = $op->op->name;
        if ($name eq 'null') {
            $name .= ' (ex-' . $op->_ex_name . ')';
        }

        my $flags = $op->op->flags;
        my @flags = map {
                        $flags & $flag_values{$_}
                            ? $_
                            : ()
                    }
                    qw(WANT_VOID WANT_SCALAR WANT_LIST KIDS PARENS REF MOD STACKED SPECIAL);

        printf("%s%s %s (%s)\n", '  'x$level, $op->class, $name,
                                 join(', ', @flags));
    });
}

sub class {
    my $self = shift;
    return substr(ref($self), rindex(ref($self), ':')+1);
}

sub siblings {
    my $self = shift;
    my $parent = $self->parent;
    return unless $parent;
    my $all_siblings = $parent->children;
    for(my $i = 0; $i < @$all_siblings; $i++) {
        if ($all_siblings->[$i] eq $self) {
            return @$all_siblings[$i+1 .. $#$all_siblings];
        }
    }
    return;
}

1;
