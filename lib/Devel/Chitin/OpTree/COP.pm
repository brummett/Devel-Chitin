package Devel::Chitin::OpTree::COP;
use base 'Devel::Chitin::OpTree';

our $VERSION = '0.07';

use strict;
use warnings;

sub pp_nextstate {
    my $self = shift;

    my @package_and_label;

    my $cur_cop = $self->_get_cur_cop;
    if ($cur_cop and !$self->is_null and $self->op->stashpv ne $cur_cop->op->stashpv) {
        push @package_and_label, 'package ' . $self->op->stashpv . ';';
    }

    if (!$self->is_null and my $label = $self->op->label) {
        push @package_and_label, "$label:";
    }

    $self->_set_cur_cop if (!$cur_cop or !$self->is_null);

    join(";\n", @package_and_label);
}
*pp_dbstate = \&pp_nextstate;
*pp_setstate = \&pp_nextstate;

1;
