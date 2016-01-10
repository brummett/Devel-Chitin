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

    my $vertical_ws = $self->_cur_cop
                        ? $self->op->line - $self->_cur_cop->op->line
                        : 0;
    $deparsed .= "\n" x $vertical_ws;

    $self->_set_cur_cop;

    $deparsed;
}
*pp_dbstate = \&pp_nextstate;
*pp_setstate = \&pp_nextstate;

1;
