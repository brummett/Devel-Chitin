package Devel::Chitin::OpTree::BINOP;
use base 'Devel::Chitin::OpTree::UNOP';

use Devel::Chitin::Version;

use strict;
use warnings;

# probably an ex-lineseq with 2 kids
*pp_lineseq = \&Devel::Chitin::OpTree::LISTOP::pp_lineseq;

sub last {
    shift->{children}->[1];
}

sub pp_sassign {
    my($self, %params) = @_;
    # normally, the args are ordered: value, variable
    my($var, $value) = $params{is_swapped}
                        ? ($self->first->deparse, $self->last->deparse)
                        : ($self->last->deparse, $self->first->deparse);
    return join(' = ', $var, $value);
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
                   [ne => '!='],
                   [ncmp => '<=>'],
                   [slt => 'lt'],
                   [sle => 'le'],
                   [sgt => 'gt'],
                   [sge => 'ge'],
                   [seq => 'eq'],
                   [sne => 'ne'],
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

    my $first = $self->first;
    if ($self->op->flags & B::OPf_STACKED
        and
        $first->op->name ne 'concat'
    ) {
        # This is an assignment-concat: $a .= 'foo'
        $first->deparse . ' .= ' . $self->last->deparse;

    } else {
        my $target = $self->_maybe_targmy;
        $target . join($params{skip_concat} ? '' : ' . ',
                        $first->deparse(%params),
                        $self->last->deparse(%params));
    }
}

sub pp_reverse {
    # a BINOP reverse is only acting on a single item
    # 0th child is pushmark, skip it
    'reverse(' . shift->last->deparse . ')';
}

# leave is normally a LISTOP, but this happens when this is run
# in the debugger
# sort { ; } @list
# The leave is turned into a null:
# ex-leave
#   enter
#   stub
*pp_leave = \&Devel::Chitin::OpTree::LISTOP::pp_leave;

# from B::Concise
use constant DREFAV => 32;
use constant DREFHV => 64;
use constant DREFSV => 96;

sub pp_helem {
    my $self = shift;

    my $first = $self->first;
    my($hash, $key) = ($first->deparse, $self->last->deparse);
    if ($self->_is_chain_deref('rv2hv', DREFHV)) {
        # This is a dereference, like $a->{foo}
        substr($hash, 1) . '->{' . $key . '}';
    } else {
        substr($hash, 0, 1) = '$';
        "${hash}{${key}}";
    }
}

sub _is_chain_deref {
    my($self, $expected_first_op, $expected_flag) = @_;
    my $child = $self->first;
    return unless $child->isa('Devel::Chitin::OpTree::UNOP');

    $child->op->name eq $expected_first_op
    and
    $child->first->op->private & $expected_flag
}

sub pp_aelem {
    my $self = shift;
    my $first = $self->first;

    my($array, $elt) = ($first->deparse, $self->last->deparse);
    if ($self->is_null
        and
        $first->op->name eq 'aelemfast_lex'
        and
        $self->last->is_null
    ) {
        $array;

    } elsif ($self->_is_chain_deref('rv2av', DREFAV)) {
        # This is a dereference, like $a->[1]
        substr($array, 1) . '->[' . $elt . ']';

    } else {
        substr($array, 0, 1) = '$';
        my $idx = $self->last->deparse;
        "${array}[${idx}]";
    }
}

# Operators
#               OP name         operator    targmy?
foreach my $a ( [ pp_add        => '+',     1 ],
                [ pp_i_add      => '+',     1 ],
                [ pp_subtract   => '-',     1 ],
                [ pp_i_subtract => '-',     1 ],
                [ pp_multiply   => '*',     1 ],
                [ pp_i_multiply => '*',     1 ],
                [ pp_divide     => '/',     1 ],
                [ pp_i_divide   => '/',     1 ],
                [ pp_modulo     => '%',     1 ],
                [ pp_i_modulo   => '%',     1 ],
                [ pp_pow        => '**',    1 ],
                [ pp_left_shift => '<<',    1 ],
                [ pp_right_shift => '>>',   1 ],
                [ pp_repeat     => 'x',     0 ],
                [ pp_bit_and    => '&',     0 ],
                [ pp_bit_or     => '|',     0 ],
                [ pp_bit_xor    => '^',     0 ],
                [ pp_xor        => 'xor',   0 ],
                
) {
    my($pp_name, $perl_name, $targmy) = @$a;
    my $sub = sub {
        my $self = shift;

        if ($self->op->flags & B::OPf_STACKED) {
            # This is an assignment op: +=
            my $first = $self->first->deparse;
            "$first ${perl_name}= " . $self->last->deparse;
        } else {
            my $target = $targmy ? $self->_maybe_targmy : '';
            $target . $self->first->deparse . " $perl_name " . $self->last->deparse;
        }
    };
    no strict 'refs';
    *$pp_name = $sub;
}

1;
