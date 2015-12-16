package Devel::Chitin::OpTree::UNOP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;

use strict;
use warnings;

sub first {
    shift->{children}->[0];
}

sub d_leavesub {
    my $self = shift;
    $self->first->deparse;
}

sub d_null {
    my $self = shift;
    #print "found a null: ",$self->op->name,"\n";
    $self->first->deparse;
}

sub d_srefgen {
    my $self = shift;
    '\\' . $self->first->deparse;
}

sub d_rv2sv {
    my $self = shift;
    '$' . $self->first->deparse;
}

1;
