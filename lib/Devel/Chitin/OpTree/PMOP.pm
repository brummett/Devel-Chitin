package Devel::Chitin::OpTree::PMOP;
use base 'Devel::Chitin::OpTree::LISTOP';

use Devel::Chitin::Version;
use B qw(PMf_CONTINUE PMf_ONCE PMf_GLOBAL PMf_MULTILINE PMf_KEEP PMf_SINGLELINE
         PMf_EXTENDED RXf_PMf_KEEPCOPY PMf_FOLD OPf_KIDS);

use strict;
use warnings;

sub pp_qr {
    shift->_match_op('qr')
}

sub _match_op {
    my($self, $operator) = @_;

    my $match_flags = $self->op->pmflags;
    my $flags = join('', map { $match_flags & $_->[0] ? $_->[1] : '' }
                            (   [ PMf_CONTINUE,     'c' ],
                                [ PMf_ONCE,         'o' ],
                                [ PMf_GLOBAL,       'g' ],
                                [ PMf_FOLD,         'i' ],
                                [ PMf_MULTILINE,    'm' ],
                                [ PMf_KEEP,         'o' ],
                                [ PMf_SINGLELINE,   's' ],
                                [ PMf_EXTENDED,     'x' ],
                                [ RXf_PMf_KEEPCOPY, 'p' ],
                            ));

    my $children = $self->children;
    my $re = @$children == 1
                ? $children->[0]->deparse
                : $self->op->precomp;

    "${operator}/${re}/${flags}";
}

1;
