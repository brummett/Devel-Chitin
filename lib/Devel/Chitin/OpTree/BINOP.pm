package Devel::Chitin::OpTree::BINOP;
use base 'Devel::Chitin::OpTree::UNOP';

use Devel::Chitin::Version;

use strict;
use warnings;

sub last {
    shift->{children}->[1];
}

sub pp_sassign {
    my $self = shift;
    return join(' = ', $self->last->deparse, $self->first->deparse);
}

sub pp_aassign {
    my $self = shift;

    my $container;
    if ($self->is_null
        and
            # assigning-to is optimized away
            $self->last->is_null and $self->last->_ex_name eq 'pp_list'
            and
            $self->last->children->[1]->is_null and $self->last->children->[1]->is_array_container
        and
            # value is an in-place sort: @a = sort @a;
            $self->first->is_null and $self->first->_ex_name eq 'pp_list'
            and
            $self->first->children->[1]->op->name eq 'sort'
            and
            $self->first->children->[1]->op->private & B::OPpSORT_INPLACE
    ) {
        # since we're optimized away, we can't find out what variable we're
        # assigning .  It's the variable the sort is acting on.
        $container = $self->first->children->[1]->children->[-1]->deparse;

    } else {
        $container = $self->last->deparse;
    }

    "$container = " . $self->first->deparse;
}

sub pp_list {
    my $self = shift;

    # 'list' is usually a LISTOP, but if we got here's it's because we're
    # actually a 'null' ex-list, and there's only one item in the list.
    # $self->first will be a pushmark
    # @list = @other_list;
    # We can emit a value without surrounding parens unless it's a scalar
    # being assigned to

    my $contents = $self->last->deparse;

    if ($self->last->is_scalar_container) {
        "(${contents})";

    } else {
        $contents;
    }
}

foreach my $cond ( [lt => '<'],
                   [le => '<='],
                   [gt => '>'],
                   [ge => '>='],
                   [eq => '=='],
                   [ncmp => '<=>'],
                   [slt => 'lt'],
                   [sle => 'le'],
                   [sgt => 'gt'],
                   [sge => 'ge'],
                   [seq => 'eq'],
                   [scmp => 'cmp'],
                )
{
    my $expr = ' ' . $cond->[1] . ' ';
    my $sub = sub {
        my $self = shift;
        return join($expr, $self->first->deparse, $self->last->deparse);
    };
    my $subname = 'pp_' . $cond->[0];
    no strict 'refs';
    *$subname = $sub;
}

sub pp_aelem {
    my $self = shift;
    if ($self->is_null
        and
        $self->first->op->name eq 'aelemfast_lex'
        and
        $self->last->is_null
    ) {
        $self->first->deparse;

    } else {
        my $array_name = substr($self->first->deparse, 1); # remove the sigil
        my $idx = $self->last->deparse;
        "\$${array_name}[${idx}]";
    }
}

sub pp_stringify {
    my $self = shift;

    unless ($self->first->op->name eq 'null'
            and
            $self->first->_ex_name eq 'pp_pushmark'
    ) {
        die "unknown stringify ".$self->first->op->name;
    }

    my $children = $self->children;
    unless (@$children == 2) {
        die "expected 2 children but got " . scalar(@$children)
            . ': ' . join(', ', map { $_->op->name } @$children);
    }

    my $target = $self->_maybe_targmy;

    "${target}qq(" . $children->[1]->deparse(skip_concat => 1, skip_quotes => 1) . ')';
}

sub pp_concat {
    my $self = shift;
    my %params = @_;

    my $target = $self->_maybe_targmy;

    $target . join($params{skip_concat} ? '' : ' . ',
                    $self->first->deparse(%params),
                    $self->last->deparse(%params));
}

sub pp_reverse {
    # a BINOP reverse is only acting on a single item
    # 0th child is pushmark, skip it
    'reverse ' . shift->last->deparse;
}

# leave is normally a LISTOP, but this happens when this is run
# in the debugger
# sort { ; } @list
# The leave is turned into a null:
# ex-leave
#   enter
#   stub
sub pp_leave {
    shift->last->deparse;
}

1;
