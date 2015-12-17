package Devel::Chitin::OpTree::UNOP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;
use B qw(ppname);

use strict;
use warnings;

sub first {
    shift->{children}->[0];
}

sub pp_leavesub {
    my $self = shift;
    $self->first->deparse;
}

sub pp_null {
    my $self = shift;
    #print "found a null: ",$self->op->name,"\n";
    my $bounce = $self->_ex_name();
    $self->$bounce();
}

sub _ex_name {
    my $self = shift;
    if ($self->op->name eq 'null') {
        ppname($self->op->targ);
    }
}

sub pp_srefgen {
    my $self = shift;
    '\\' . $self->first->deparse;
}

sub pp_rv2sv {
    my $self = shift;
    '$' . $self->first->deparse;
}

1;
