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
    # We can emit a value without surrounding parens
    $self->last->deparse();
}

foreach my $cond ( [lt => '<'],
                   [le => '<='],
                   [gt => '>'],
                   [ge => '>='],
                   [eq => '=='],
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

1;
