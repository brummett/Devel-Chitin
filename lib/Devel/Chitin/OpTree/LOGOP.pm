package Devel::Chitin::OpTree::LOGOP;
use base 'Devel::Chitin::OpTree::UNOP';

use Devel::Chitin::Version;

use strict;
use warnings;

sub other {
    shift->{children}->[1];
}

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
    _deparse_map_grep(shift, 'map');
}

sub pp_grepwhile {
    _deparse_map_grep(shift, 'grep');
}

sub _deparse_map_grep {
    my($self, $function) = @_;

    my $mapstart = $self->first;
    my $children = $mapstart->children;

    my $block_or_expr = $mapstart->children->[1]->first;
    $block_or_expr = $block_or_expr->first if $block_or_expr->is_null;

    my @map_params = map { $_->deparse } @$children[2 .. $#$children];
    if ($block_or_expr->is_scopelike) {
        # map { ... } @list
        my $use_parens = (@map_params > 1 or substr($map_params[0], 0, 1) ne '@');

        "${function} " . $block_or_expr->deparse . ' '
            . ($use_parens ? '(' : '')
            . join(', ', @map_params)
            . ($use_parens ? ')' : '');

    } else {
        # map(expr, @list)

        "${function}("
            . $block_or_expr->deparse
            . ', '
            . join(', ', @map_params)
        . ')';
    }
}

sub pp_and {
    my $self = shift;
    my $left = $self->first->deparse;
    my $right = $self->other->deparse;
    if ($self->other->is_scopelike) {
        $right = _format_if_block($right);
        "if ($left) $right";
    } else {
        "$left && $right";
    }
}

sub _format_if_block {
    my $code = shift;
    unless (index($code,"\n") >=0 ) {
        # make even one-liner blocks indented
        $code =~ s/^{ /{\n\t/;
        $code =~ s/ }$/\n}/;
    }
    $code =~ s/^{ /{\n\t/;
    $code;
}

sub pp_or {
    my $self = shift;
    $self->first->deparse . ' || ' . $self->other->deparse;
}

sub pp_andassign { _and_or_assign(shift, '&&=') }
sub pp_orassign { _and_or_assign(shift, '||=') }
sub _and_or_assign {
    my($self, $op) = @_;
    my $var = $self->first->deparse;
    my $value = $self->other->first->deparse;  # skip over sassign (other)
    join(' ', $var, $op, $value);
}

sub pp_cond_expr {
    my $self = shift;
    my $children = $self->children;

    my($cond, $true, $false) = @$children;
    my($cond_code, $true_code, $false_code) = map { $_->deparse } ($cond, $true, $false);

    if ($true->is_scopelike and $false->is_scopelike) {
        $true_code = _format_if_block($true_code);
        $false_code = _format_if_block($false_code);
        "if ($cond_code) $true_code else $false_code";

    } else {
        $cond->deparse . ' ? ' . $true->deparse . ' : ' . $false->deparse;
    }
}

1;
