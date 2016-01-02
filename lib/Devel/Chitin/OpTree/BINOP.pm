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

*pp_aassign = \&pp_sassign;

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

1;
