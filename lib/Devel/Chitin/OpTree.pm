package Devel::Chitin::OpTree;

use strict;
use warnings;

use Devel::Chitin::Version;

use Carp;
use Scalar::Util qw(blessed);
use B qw(ppname);

use Devel::Chitin::OpTree::UNOP;
use Devel::Chitin::OpTree::SVOP;
use Devel::Chitin::OpTree::PADOP;
use Devel::Chitin::OpTree::COP;
use Devel::Chitin::OpTree::PVOP;
use Devel::Chitin::OpTree::METHOP;
use Devel::Chitin::OpTree::BINOP;
use Devel::Chitin::OpTree::LOGOP;
use Devel::Chitin::OpTree::LOGOP_AUX;
use Devel::Chitin::OpTree::LISTOP;
use Devel::Chitin::OpTree::LOOP;
use Devel::Chitin::OpTree::PMOP;

sub build_from_location {
    my($class, $start) = @_;

    my($start_op, $cv) = _determine_start_of($start);

    # adapted from B::walkoptree_slow
    my @parents;
    my $build_walker;
    $build_walker = sub {
        my $op = shift;

        my $self = $class->new(op => $op, cv => $cv);

        my @children;
        if ($$op && ($op->flags & B::OPf_KIDS)) {
            unshift(@parents, $self);
            for (my $kid_op = $op->first; $$kid_op; $kid_op = $kid_op->sibling) {
                push @children, $build_walker->($kid_op);
            }
            shift(@parents);
        }

        if (B::class($op) eq 'PMOP'
            and ref($op->pmreplroot)
            and ${$op->pmreplroot}
            and $op->pmreplroot->isa('B::OP')
        ) {
            unshift @parents, $self;
            push @children, $build_walker->($op->pmreplroot);
            shift @parents;
        }

        @$self{'parent','children'} = ($parents[0], \@children);
        $self;
    };

    $build_walker->($start_op);
}

sub _determine_start_of {
    my $start = shift;

    unless (blessed($start) and $start->isa('Devel::Chitin::Location')) {
        Carp::croak('build_from_location() requires a Devel::Chitin::Location as an argument');
    }

    if ($start->package eq 'main' and $start->subroutine eq 'MAIN') {
        return (B::main_root(), B::main_cv);

    } elsif ($start->subroutine =~ m/::__ANON__\[\S+:\d+\]/) {
        Carp::croak(q(Don't know how to handle anonymous subs yet));

    } else {
        my $subname = join('::', $start->package, $start->subroutine);
        my $subref = do { no strict 'refs'; \&$subname };
        my $cv = B::svref_2object($subref);
        return ($cv->ROOT, $cv);
    }
}

sub new {
    my($class, %params) = @_;
    unless (exists $params{op}) {
        Carp::croak(q{'op' is a required parameter of new()});
    }

    my $final_class = _class_for_op($params{op});

    my $self = bless \%params, $final_class;
    $self->_build();
    return $self;
}

sub _class_for_op {
    my $op = shift;
    my $b_class = B::class($op);
    if ($b_class eq 'OP') {
        return __PACKAGE__,
    } elsif ($b_class eq 'UNOP'
             and $op->name eq 'null'
             and $op->flags & B::OPf_KIDS
    ) {
        my $num_children = 0;
        for (my $kid_op = $op->first; $$kid_op; $kid_op = $kid_op->sibling) {
            $num_children++ ;
        }
        if ($num_children > 2) {
            return join('::', __PACKAGE__, 'LISTOP');
        } elsif ($num_children > 1) {
            return join('::', __PACKAGE__, 'BINOP');

        } else {
            return join('::', __PACKAGE__, 'UNOP');
        }
    } else {
        join('::', __PACKAGE__, B::class($op));
    }
}

sub _build { }

sub op { shift->{op} }
sub parent { shift->{parent} }
sub children { shift->{children} }
sub cv { shift->{cv} }

sub walk_preorder {
    my($self, $cb) = @_;
    $_->walk_preorder($cb) foreach (@{ $self->children });
    $cb->($self);
}

sub walk_inorder {
    my($self, $cb) = @_;
    $cb->($self);
    $_->walk_inorder($cb) foreach (@{ $self->children } );
}

sub deparse {
    my $self = shift;
    my $bounce = 'pp_' . $self->op->name;
    $self->$bounce(@_);
}

sub _deparsed_children {
    my $self = shift;
    return grep { $_ }
           map { $_->deparse }
           @{ $self->children };
}

sub is_null {
    return shift->op->name eq 'null';
}

sub pp_null {
    my $self = shift;
    my $bounce = $self->_ex_name;

    if ($bounce eq 'pp_null') {
        if (@{$self->children} == 2
            and $self->first->is_scalar_container
            and $self->last->op->name eq 'readline'
        ) {
            # not sure why this gets special-cased...
            $self->Devel::Chitin::OpTree::BINOP::pp_sassign(is_swapped => 1);
        } else {
            ";\n"   # maybe a COP that got optimized away?
        }

    } else {
        $self->$bounce(@_);
    }
}

# These are nextstate/dbstate that got optimized away to null
*pp_nextstate = \&Devel::Chitin::OpTree::COP::pp_nextstate;
*pp_dbstate = \&Devel::Chitin::OpTree::COP::pp_dbstate;

sub pp_padsv {
    my $self = shift;
    # These are 'my' variables.  We're omitting the 'my' because
    # that happens at compile time
    $self->_padname_sv->PV;
}
*pp_padav = \&pp_padsv;
*pp_padhv = \&pp_padsv;

sub pp_aelemfast_lex {
    my $self = shift;
    my $list_name = substr($self->pp_padav, 1); # remove the sigil
    "\$${list_name}[" . $self->op->private . ']';
}

sub pp_padrange {
    my $self = shift;
    # These are 'my' variables.  We're omitting the 'my' because
    # that happens at compile time
    $self->_padname_sv->PV;
}

sub pp_pushmark {
    my $self = shift;

    die "didn't expect to deparse a pushmark";
}

sub _padname_sv {
    my $self = shift;
#    print "in padname_sv\n";
#    print "PADLIST: ",$self->cv->PADLIST,"\n";
#    print "ARRAYelt(0): ",$self->cv->PADLIST->ARRAYelt(0),"\n";
    return $self->cv->PADLIST->ARRAYelt(0)->ARRAYelt( $self->op->targ );
}

sub _ex_name {
    my $self = shift;
    if ($self->op->name eq 'null') {
        ppname($self->op->targ);
    }
}

my %flag_values = (
    WANT_VOID => B::OPf_WANT_VOID,
    WANT_SCALAR => B::OPf_WANT_SCALAR,
    WANT_LIST => B::OPf_WANT_LIST,
    KIDS => B::OPf_KIDS,
    PARENS => B::OPf_PARENS,
    REF => B::OPf_REF,
    MOD => B::OPf_MOD,
    STACKED => B::OPf_STACKED,
    SPECIAL => B::OPf_SPECIAL,
);
sub print_as_tree {
    my $self = shift;
    $self->walk_inorder(sub {
        my $op = shift;
        my($level, $parent) = (0, $op);
        $level++ while($parent = $parent->parent);
        my $name = $op->op->name;
        if ($name eq 'null') {
            $name .= ' (ex-' . $op->_ex_name . ')';
        }

        my $flags = $op->op->flags;
        my @flags = map {
                        $flags & $flag_values{$_}
                            ? $_
                            : ()
                    }
                    qw(WANT_VOID WANT_SCALAR WANT_LIST KIDS PARENS REF MOD STACKED SPECIAL);

        printf("%s%s %s (%s)\n", '  'x$level, $op->class, $name,
                                 join(', ', @flags));
    });
}

sub class {
    my $self = shift;
    return substr(ref($self), rindex(ref($self), ':')+1);
}

sub nearest_cop {
    my $self = shift;

    my $parent = $self->parent;
    return unless $parent;
    my $siblings = $parent->children;
    return unless $siblings and @$siblings;

    for (my $i = 0; $i < @$siblings; $i++) {
        my $sib = $siblings->[$i];
        if ($sib eq $self) {
            # Didn't find it on one of the siblings already executed, try the parent
            return $parent->nearest_cop();

        } elsif ($sib->class eq 'COP') {
            return $sib;
        }
    }
    return;
}

sub pp_const {
    q('constant optimized away');
}

# Usually, rand/srand/pop/shift is an UNOP, but with no args, it's a base-OP
sub pp_rand {
    my $target = shift->_maybe_targmy;
    "${target}rand()";
}
sub pp_srand {
    my $target = shift->_maybe_targmy;
    "${target}srand()";
}
sub pp_pop { 'pop()' }
sub pp_shift { 'shift()' }
sub pp_close { 'close()' }
sub pp_getc { 'getc()' }
sub pp_tell { 'tell()' }
sub pp_enterwrite { 'write()' }

# Chdir can be either a UNOP or base-OP
sub pp_chdir {
    my $self = shift;
    my $children = $self->children;
    my $target = $self->_maybe_targmy;
    if (@$children) {
        "${target}chdir(" . $children->[0]->deparse . ')';
    } else {
        "${target}chdir()";
    }
}

sub pp_enter { '' }
sub pp_stub { ';' }

sub pp_ggrent { 'getgrent()' }
sub pp_eggrent { 'endgrent()' }
sub pp_ehostent { 'endhostent()' }
sub pp_enetent { 'endnetent()' }
sub pp_egrent { 'endgrent()' }
sub pp_epwent { 'endpwent()' }
sub pp_spwent { 'setpwent()' }
sub pp_sgrent { 'setgrent()' }
sub pp_gpwent { 'getpwent()' }
sub pp_getlogin { 'getlogin()' }

sub pp_eof {
    shift->op->flags & B::OPf_SPECIAL
        ? 'eof()'
        : 'eof';
}

# file test operators
# These actually show up as UNOPs (usually) and SVOPs (-X _) but it's
# convienent to put them here in the base class
foreach my $a ( [ pp_fteread    => '-r' ],
                [ pp_ftewrite   => '-w' ],
                [ pp_fteexec    => '-x' ],
                [ pp_fteowned   => '-o' ],
                [ pp_ftrread    => '-R' ],
                [ pp_ftrwrite   => '-W' ],
                [ pp_ftrexec    => '-X' ],
                [ pp_ftrowned   => '-O' ],
                [ pp_ftis       => '-e' ],
                [ pp_ftzero     => '-z' ],
                [ pp_ftsize     => '-s' ],
                [ pp_ftfile     => '-f' ],
                [ pp_ftdir      => '-d' ],
                [ pp_ftlink     => '-l' ],
                [ pp_ftpipe     => '-p' ],
                [ pp_ftblk      => '-b' ],
                [ pp_ftsock     => '-S' ],
                [ pp_ftchr      => '-c' ],
                [ pp_fttty      => '-t' ],
                [ pp_ftsuid     => '-u' ],
                [ pp_ftsgid     => '-g' ],
                [ pp_ftsvtx     => '-k' ],
                [ pp_fttext     => '-T' ],
                [ pp_ftbinary   => '-B' ],
                [ pp_ftmtime    => '-M' ],
                [ pp_ftatime    => '-A' ],
                [ pp_ftctime    => '-C' ],
) {
    my($pp_name, $perl_name) = @$a;
    my $sub = sub {
        my $self = shift;
        if ($self->class eq 'UNOP') {
            my $fh = $self->children->[0]->deparse;
            join(' ', $perl_name,
                        $fh eq '$_' ? () : $fh);
        } else {
            # it's an SVOP
            my $fh = $self->Devel::Chitin::OpTree::SVOP::pp_gv();
            $perl_name . ' ' . $fh;
        }
    };
    no strict 'refs';
    *$pp_name = $sub;
}

# The return values for some OPs is encoded specially, and not through a
# normal sassign
sub _maybe_targmy {
    my $self = shift;

    if ($self->op->private & B::OPpTARGET_MY) {
        $self->_padname_sv->PV . ' = ';
    } else {
        '';
    }
}

# return true for scalar things we can assign to
sub is_scalar_container {
    my $self = shift;
    my $op_name = $self->is_null
                    ? $self->_ex_name
                    : $self->op->name;
    {   rv2sv => 1,
        pp_rv2sv => 1,
        padsv => 1,
        pp_padsv => 1,
    }->{$op_name};
}

sub is_array_container {
    my $self = shift;
    my $op_name = $self->is_null
                    ? $self->_ex_name
                    : $self->op->name;
    {   rv2av => 1,
        pp_rv2av => 1,
        padav => 1,
        pp_padav => 1,
    }->{$op_name};
}

sub is_scopelike {
    my $self = shift;
    my $op_name = $self->is_null
                    ? $self->_ex_name
                    : $self->op->name;
    {   scope => 1,
        pp_scope => 1,
        leave => 1,
        pp_leave => 1,
    }->{$op_name};
}

my %control_chars = ((map { chr($_) => '\c'.chr($_ + 64) } (1 .. 26)),  # \cA .. \cZ
                     "\c@" => '\c@', "\c[" => '\c[');
my $control_char_rx = join('|', sort keys %control_chars);
sub _escape_for_double_quotes {
    my($self, $str, %params) = @_;

    $str =~ s/\\/\\\\/g;
    $str =~ s/\a/\\a/g;  # alarm
    $str =~ s/\cH/\\b/g unless $params{in_regex}; # backspace
    $str =~ s/\e/\\e/g;  # escape
    $str =~ s/\f/\\f/g;  # form feed
    $str =~ s/\n/\\n/g;  # newline
    $str =~ s/\r/\\r/g;  # CR
    $str =~ s/\t/\\t/g;  # tab
    $str =~ s/"/\\"/g;
    $str =~ s/($control_char_rx)/$control_chars{$1}/ge;
    $str =~ s/([[:^print:]])/sprintf('\x{%x}', ord($1))/ge;

    $str;
}

1;
