package Devel::Chitin::OpTree::LOGOP;
use base 'Devel::Chitin::OpTree::UNOP';

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_entertry { '' }

sub pp_regcomp {
    my $self = shift;
    my %params = @_;

    my $rx_op = $self->first;
    $rx_op = $rx_op->first if $rx_op->op->name eq 'regcmaybe';

    join('', $rx_op->deparse(skip_parens => 1, skip_quotes => 1, join_with => '', %params));
}

sub pp_substcont {
    my $self = shift;
    join('', $self->first->deparse(skip_concat => 1, skip_quotes => 1));
}

# The arrangement looks like this
# mapwhile
#    mapstart
#        padrange
#        null
#            block-or-expr
#                ...
#            list-0
#            list-1
#            ...
sub pp_mapwhile {
    my $self = shift;

    my $mapstart = $self->first;
    my $children = $mapstart->children;

    my $block_or_expr = $mapstart->children->[1]->first;
    $block_or_expr = $block_or_expr->first if $block_or_expr->is_null;

    my @map_params = map { $_->deparse } @$children[2 .. $#$children];
    if ($block_or_expr->is_scopelike) {
        my $use_parens = @map_params > 1 or substr($map_params[0], 1, 0) ne '@';

        my $skip = $block_or_expr->op->name eq 'scope'
                        ? 1     # normal execution, skip an ex-nextstate
                        : 2;    # run in debugger, skip enter and dbstate

        'map { ' . $block_or_expr->deparse(skip => $skip) . ' } '  # skip enter and nextstate
            . ($use_parens ? '( ' : '')
            . join(', ', @map_params)
            . ($use_parens ? ' )' : '');

    } else {
        'map('
            . $block_or_expr->deparse
            . ', '
            . join(', ', @map_params)
        . ')';
    }
}

1;
