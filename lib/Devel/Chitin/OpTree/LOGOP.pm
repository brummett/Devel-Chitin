package Devel::Chitin::OpTree::LOGOP;
use base 'Devel::Chitin::OpTree::UNOP';

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_entertry { '' }

sub pp_regcomp {
    my $self = shift;

    my $rx_op = $self->first;
    $rx_op = $rx_op->first if $rx_op->op->name eq 'regcmaybe';

    join('', $rx_op->deparse(skip_parens => 1, skip_quotes => 1, join_with => ''));
}

1;
