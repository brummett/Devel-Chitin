package Devel::Chitin::OpTree::COP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;

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

sub X_should_insert_semicolon {
    my $self = shift;
    my $is_subsequent_cop = $self->_get_cur_cop_in_scope;
    return '' unless $is_subsequent_cop;

    my $prev = ($self->pre_siblings)[-1];

    return '' if $prev
                 and $prev->isa('Devel::Chitin::OpTree::COP')
                 and $prev->op->line == $self->op->line;

    if ($prev
        and (
              # $prev was some kind of block
              ( $prev->is_scopelike
                and
                ! $prev->_deparse_postfix_while
              )
              or
              # $prev was the end of an if-block
              ( $prev->children->[0]
                and $prev->children->[0]->children->[1]
                and $prev->children->[0]->children->[1]->is_scopelike
              )
        )
    ) {
        return ''; # don't put a semi after a block-like construct
    }

    1;
}

1;
