package Devel::Chitin::OpTree::COP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_nextstate {
    my $self = shift;

    my $deparsed = '';
    if ($self->_should_insert_semicolon) {
        $deparsed .= ';';
    }

    my $cur_cop = $self->_get_cur_cop;
    my $vertical_ws = $cur_cop
                        ? $self->op->line - $cur_cop->op->line
                        : 0;

    if ($cur_cop and $self->op->stashpv ne $cur_cop->op->stashpv) {
        $deparsed .= "\npackage " . $self->op->stashpv . ";";
        $vertical_ws--;
    }

    if ($self->op->label) {
        $deparsed .= "\n" if $self->_should_insert_semicolon;
        $deparsed .= $self->op->label . ': ';
        $vertical_ws--;
    }

    $deparsed .= "\n" x $vertical_ws;

    $self->_set_cur_cop;

    $deparsed;
}
*pp_dbstate = \&pp_nextstate;
*pp_setstate = \&pp_nextstate;

sub _should_insert_semicolon {
    shift->_get_cur_cop_in_scope;
}

1;
