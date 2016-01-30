package Devel::Chitin::OpTree::COP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_nextstate {
    my $self = shift;

    my $deparsed = '';
    if (_should_insert_semicolon($self)) {
        $deparsed .= ';';
    }

    my $cur_cop = $self->_get_cur_cop;
    my $vertical_ws = $cur_cop
                        ? $self->op->line - $cur_cop->op->line
                        : 0;
    $vertical_ws = 1 if ($vertical_ws > 1);

    if ($cur_cop and $self->op->stashpv ne $cur_cop->op->stashpv) {
        $deparsed .= "\npackage " . $self->op->stashpv . ";\n";
        $vertical_ws--;
    }

    if ($self->op->label) {
        $deparsed .= "\n" if $self->_should_insert_semicolon;
        $deparsed .= $self->op->label . ":\n";
        $vertical_ws--;
    }

    $deparsed .= "\n" x $vertical_ws;

    $self->_set_cur_cop;

    $deparsed;
}
*pp_dbstate = \&pp_nextstate;
*pp_setstate = \&pp_nextstate;

sub _should_insert_semicolon {
    my $self = shift;
    my $is_subsequent_cop = $self->_get_cur_cop_in_scope;
    return '' unless $is_subsequent_cop;

    my $prev = ($self->pre_siblings)[-1];
    if ($prev
        and $prev->is_null
        and $prev->first->class eq 'LOGOP'
        and $prev->first->other->is_scopelike
    ) {
        return ''; # don't put a semi after a block-like construct
    }

    1;
}

1;
