package Devel::Chitin::OpTree::UNOP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;

use strict;
use warnings;

sub first {
    shift->{children}->[0];
}

sub pp_leavesub {
    my $self = shift;
    $self->first->deparse;
}


# Normally, pp_list is a LISTOP, but this happens when a pp_list is turned
# into a pp_null by the optimizer, and it has one child
sub pp_list {
    my $self = shift;
    $self->first->deparse;
}

sub pp_srefgen {
    my $self = shift;
    '\\' . $self->first->deparse;
}

sub pp_rv2sv { '$' . shift->first->deparse }
sub pp_rv2av { '@' . shift->first->deparse }
sub pp_rv2hv { '%' . shift->first->deparse }
sub pp_rv2cv {
    my $self = shift;
    # The null case is the most common.  not-null happens
    # with undef(&function::name) and generates this optree:
    # undef
    #   rv2cv
    #     ex-list
    #       ex-pushmark
    #       ex-rv2cv
    #           gv(*function::name)
    # We only want the sigil prepended once
    my $sigil = $self->is_null ? '' : '&';
    $sigil . $self->first->deparse;
}

sub pp_rv2gv {
    my($self, %params) = @_;
    if ($self->op->flags & B::OPf_SPECIAL    # happens in syswrite($fh, ...) and other I/O functions
        or
        $self->op->private & B::OPpDEREF_SV  # happens in select($fh)
        or
        $params{skip_sigil}  # this is a hack for "print F ..." to deparse correctly :(
    ) {
        return $self->first->deparse;
    } else {
        return '*' . $self->first->deparse;
    }
}

sub pp_entersub {
    my $self = shift;

    my @params_ops;
    if ($self->first->op->flags & B::OPf_KIDS) {
        # normal sub call
        # first is a pp_list containing a pushmark, followed by the arg
        # list, followed by the sub name
        (undef, @params_ops) = @{ $self->first->children };

    } elsif ($self->first->op->name eq 'pushmark'
            or
            $self->first->op->name eq 'padrange'
    ) {
        # method call
        # the args are children of $self: a pushmark/padrange, invocant, then args, then method_named() with the method name
        (undef, undef, @params_ops) = @{ $self->children };

    } else {
        die "unknown entersub first op " . $self->first->op->name;
    }
    my $sub_name_op = pop @params_ops;

    return _deparse_sub_invocation($sub_name_op)
            . '('
                . join(', ', map { $_->deparse } @params_ops)
            . ')';
}

sub _deparse_sub_invocation {
    my $op = shift;

    my $op_name = $op->op->name;
    if ($op_name eq 'rv2cv'
        or
        ( $op->is_null and $op->_ex_name eq 'pp_rv2cv' )
    ) {
        # subroutine call

        if ($op->first->op->name eq 'gv') {
            # normal sub call: Some::Sub::named(...)
            $op->deparse;
        } else {
            # subref call
            $op->deparse . '->';
        }

    } elsif ($op_name eq 'method_named' or $op_name eq 'method') {
        join('->',  $op->parent->children->[1]->deparse(skip_quotes => 1),  # class
                    $op->deparse(skip_quotes => 1));

    } else {
        die "unknown sub invocation for $op_name";
    }
}

sub pp_method {
    my $self = shift;
    $self->first->deparse;
}

sub pp_av2arylen {
    my $self = shift;

    substr(my $list_name = $self->first->deparse, 0, 1, ''); # remove sigil
    '$#' . $list_name;
}

sub pp_delete {
    my $self = shift;
    my $local = $self->op->private & B::OPpLVAL_INTRO
                    ? 'local '
                    : '';
    "delete(${local}" . $self->first->deparse . ')';
}

sub pp_exists {
    my $self = shift;
    my $arg = $self->first->deparse;
    if ($self->op->private & B::OPpEXISTS_SUB) {
        $arg = "&${arg}";
    }
    "exists($arg)";
}

sub pp_readline {
    my $self = shift;
    my $arg = $self->first->deparse;
    my $first = $self->first;

    my $flags = $self->op->flags;
    if ($flags & B::OPf_SPECIAL) {
        # <$fh>
        "<${arg}>";

    } elsif ($self->first->op->name eq 'gv') {
        # <F>
        "<${arg}>"

#    } elsif ($flags & B::OPf_STACKED) {
#        # readline(*F)
#        "readline(${arg})"
#
#    } else {
#        # readline($fh)
#        "readline(${arg})";
#    }
    } else {
        "readline(${arg})";
    }
}

sub pp_undef {
    #'undef(' . shift->first->deparse . ')'
    my $self = shift;
    my $arg = $self->first->deparse;
    if ($arg =~ m/::/) {
        $DB::single=1 if $arg =~ m/::/;
        $arg = $self->first->deparse;
    }
    "undef($arg)";
}

# Functions that can operate on $_
#                   OP name        Perl fcn    targmy?
foreach my $a ( [ pp_entereval  => 'eval',      0 ],
                [ pp_schomp     => 'chomp',     1 ],
                [ pp_schop      => 'chop',      1 ],
                [ pp_chr        => 'chr',       1 ],
                [ pp_hex        => 'hex',       1 ],
                [ pp_lc         => 'lc',        0 ],
                [ pp_lcfirst    => 'lcfirst',   0 ],
                [ pp_uc         => 'uc',        0 ],
                [ pp_ucfirst    => 'ucfirst',   0 ],
                [ pp_length     => 'length',    1 ],
                [ pp_oct        => 'oct',       1 ],
                [ pp_ord        => 'ord',       1 ],
                [ pp_abs        => 'abs',       1 ],
                [ pp_cos        => 'cos',       1 ],
                [ pp_sin        => 'sin',       1 ],
                [ pp_exp        => 'exp',       1 ],
                [ pp_int        => 'int',       1 ],
                [ pp_log        => 'log',       1 ],
                [ pp_sqrt       => 'sqrt',      1 ],
                [ pp_quotemeta  => 'quotemeta', 1 ],
                [ pp_chroot     => 'chroot',    1 ],
) {
    my($pp_name, $perl_name, $targmy) = @$a;
    my $sub = sub {
        my $self = shift;
        my $arg = $self->first->deparse;

        my $target = $targmy ? $self->_maybe_targmy : '';
        "${target}${perl_name}("
            . ($arg eq '$_' ? '' : $arg)
            . ')';
    };
    no strict 'refs';
    *$pp_name = $sub;
}

# Functions that don't operate on $_
#                   OP name        Perl fcn    targmy?
foreach my $a ( [ pp_scalar     => 'scalar',    0 ],
                [ pp_rand       => 'rand',      1 ],
                [ pp_srand      => 'srand',     1 ],
                [ pp_pop        => 'pop',       0 ],
                [ pp_shift      => 'shift',     0 ],
                [ pp_each       => 'each',      0 ],
                [ pp_keys       => 'keys',      0 ],
                [ pp_values     => 'values',    0 ],
                [ pp_ggrgid     => 'getgrgid',  0 ],
                [ pp_gpwuid     => 'getpwuid',  0 ],
                [ pp_gpwnam     => 'getpwnam',  0 ],
                [ pp_gpwent     => 'getpwent',  0 ],
                [ pp_ggrnam     => 'getgrnam',  0 ],
                [ pp_close      => 'close',     0 ],
                [ pp_closedir   => 'closedir',  0 ],
                [ pp_dbmclose   => 'dbmclose',  0 ],
                [ pp_eof        => 'eof',       0 ],
                [ pp_fileno     => 'fileno',    0 ],
                [ pp_getc       => 'getc',      0 ],
                [ pp_readdir    => 'readdir',   0 ],
                [ pp_rewinddir  => 'rewinddir', 0 ],
                [ pp_tell       => 'tell',      0 ],
                [ pp_telldir    => 'telldir',   0 ],
                [ pp_enterwrite => 'write',     0 ],
) {
    my($pp_name, $perl_name, $targmy) = @$a;
    my $sub = sub {
        my $self = shift;
        my $arg = $self->first->deparse;

        my $target = $targmy ? $self->_maybe_targmy : '';
        "${target}${perl_name}($arg)";
    };
    no strict 'refs';
    *$pp_name = $sub;
}

# Note that there's no way to tell the difference between "!" and "not"
sub pp_not {
    my $first = shift->first;
    my $first_deparsed = $first->deparse;

    if ($first->op->name eq 'match'
        and
        $first->_has_bound_variable
    ) {
        $first_deparsed;  # The match op will turn it into $var !~ m/.../
    } else {
        '!' . $first_deparsed;
    }
}

sub pp_flop {
    my $self = shift;
    my $flip = $self->first;
    my $op = ($flip->op->flags & B::OPf_SPECIAL) ? '...' : '..';

    my $range = $flip->first;
    my $start = $range->first->deparse;
    my $end = $range->other->deparse;

    "$start $op $end";
}

# Operators
#               OP name         perl op   pre?  targmy?
foreach my $a ( [ pp_preinc     => '++',    1,  0 ],
                [ pp_i_preinc   => '++',    1,  0 ],
                [ pp_postinc    => '++',    0,  1 ],
                [ pp_i_postinc  => '++',    0,  1 ],
                [ pp_predec     => '--',    1,  0 ],
                [ pp_i_predec   => '--',    1,  0 ],
                [ pp_postdec    => '--',    0,  1 ],
                [ pp_i_postdec  => '--',    0,  1 ],
                [ pp_complement => '~',     1,  1 ],
) {
    my($pp_name, $op, $is_prefix, $is_targmy) = @$a;

    my $sub = sub {
        my $self = shift;
        my $target = $self->_maybe_targmy if $is_targmy;
        $is_prefix
            ? ($op . $self->first->deparse)
            : ($self->first->deparse . $op);
    };
    no strict 'refs';
    *$pp_name = $sub;
}

1;
