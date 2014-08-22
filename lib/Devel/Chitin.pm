use warnings;
use strict;

package Devel::Chitin;

our $VERSION = '0.04';

use Scalar::Util;
use IO::File;

use Devel::Chitin::Actionable;  # Breakpoints and Actions
use Devel::Chitin::Eval;
use Devel::Chitin::Stack;
use Devel::Chitin::Location;
use Devel::Chitin::SubroutineLocation;
use Devel::Chitin::Exception;

use base 'Exporter';
our @EXPORT_OK = qw( $VERSION );

# lexicals shared between the interface package and the DB package
my(%attached_clients,
   @attached_clients,
   %trace_clients,
   $is_initialized,
   @pending_eval,
   $current_location,
);
sub attach {
    my $self = shift;

    unless ($attached_clients{$self}) {
        $attached_clients{$self} = $self;
        push @attached_clients, $self;

        if ($is_initialized) {
            $self->init();
        }
    }
    return $self;
}

sub _turn_off_trace_if_not_needed {
    $DB::trace = %trace_clients || @watch_exprs;
}

sub detach {
    my $self = shift;
    my $deleted = delete $attached_clients{$self};
    delete $trace_clients{$self};
    _turn_off_trace_if_not_needed();
    if ($deleted) {
        for (my $i = 0; $i < @attached_clients; $i++) {
            my $same = ref($self)
                    ? Scalar::Util::refaddr($self) == Scalar::Util::refaddr($attached_clients[$i])
                    : $self eq $attached_clients[$i];
            if ($same) {
                splice(@attached_clients, $i, 1);
            }
        }
    }
    return $deleted;
}


sub _clients {
    return @attached_clients;
}

## Methods callable from client code

sub step {
    $DB::single=1;
}

sub stepover {
    local $DB::in_debugger = 1;
    $DB::single=1;
    $DB::step_over_depth = $DB::stack_depth;
    return 1;
}

sub stepout {
    $DB::single=0;
    $DB::step_over_depth = $DB::stack_depth - 1;
    return 1;
}

# Should support running to a subname, or file+line
sub continue {
    $DB::single=0;
    return 1;
}

sub trace {
    local $DB::in_debugger = 1;
    my $class = shift;
    my $rv;
    if (@_) {
        my $new_val = shift;
        if ($new_val) {
            # turning trace on
            $trace_clients{$class} = $class;
            $DB::trace = 1;
            $rv = 1;
        } else {
            # turning it off
            delete $trace_clients{$class};
            _turn_off_trace_if_not_needed();
            $rv = 0;
        }

    } else {
        # Checking value
        $rv = exists $trace_clients{$class};
    }
    return $rv;
}



sub eval {
    my($class, $eval_string, $wantarray, $cb) = @_;
    push @pending_eval, [ $eval_string, $wantarray, $cb ];
}


sub eval_at {
    my($class, $eval_string, $level) = @_;

    {   no warnings 'numeric';
        $level = 0 if ($level < 1);
    }

}

sub stack {
    return Devel::Chitin::Stack->new();
}

sub current_location {
    return $current_location;
}

sub disable_debugger {
    # Setting $^P disables single stepping and subrouting entry
    # but if the program sets $DB::single explicitly, it'll still enter DB()
    $^P = 0;  # Stops single-stepping
    $DB::debugger_disabled = 1;
}

sub is_loaded {
    my($self, $filename) = @_;
    #no strict 'refs';
    return $main::{'_<' . $filename};
}

sub loaded_files {
    my @files = grep /^_</, keys(%main::);
    return map { substr($_,2) } @files; # remove the <_
}

sub is_breakable {
    my($class, $filename, $line) = @_;

    use vars qw(@dbline);
    local(*dbline) = $main::{'_<' . $filename};
    return $dbline[$line] + 0;   # FIXME change to == 0
}

sub add_break {
    my $self = shift;
    Devel::Chitin::Breakpoint->new(@_);
}

sub get_breaks {
    my $self = shift;
    my %params = @_;
    if (defined $params{file}) {
        return Devel::Chitin::Breakpoint->get(@_);
    } else {
        return map { Devel::Chitin::Breakpoint->get(@_, file => $_) }
                $self->loaded_files;
    }
}

sub remove_break {
    my $self = shift;
    if (ref $_[0]) {
        # given a breakpoint object
        shift->delete();
    } else {
        # given breakpoint params
        Devel::Chitin::Breakpoint->delete(@_);
    }
}

sub add_action {
    my $self = shift;
    Devel::Chitin::Action->new(@_);
}

sub remove_action {
    my $self = shift;
    if (ref $_[0]) {
        # given an action object
        shift->delete();
    } else {
        # given breakpoint params
        Devel::Chitin::Action->delete(@_);
    }
}

sub get_actions {
    my $self = shift;
    my %params = @_;
    if (defined $params{file}) {
        Devel::Chitin::Action->get(@_);
    } else {
        return map { Devel::Chitin::Action->get(@_, file => $_) }
                $self->loaded_files;
    }
}

sub get_var_at_level {
    my($class, $varname, $level) = @_;

    require Devel::Chitin::GetVarAtLevel;
    return Devel::Chitin::GetVarAtLevel::get_var_at_level($varname, $level);
}


sub subroutine_location {
    my $class = shift;
    my $subname = shift;
    return Devel::Chitin::SubroutineLocation->new_from_db_sub($subname);
}

# NOTE: This postpones until a named file is loaded.
# Have another interface for postponing until a module is loaded
sub postpone {
    my($class, $filename, $sub) = @_;

    if ($class->is_loaded($filename)) {
        # already loaded, run immediately
        $sub->($filename);
    } else {
        $DB::postpone_until_loaded{$filename} ||= [];
        push @{ $DB::postpone_until_loaded{$filename} }, $sub;
    }
}

sub user_requested_exit {
    $DB::user_requested_exit = 1;
}

sub file_source {
    my($class, $file) = @_;

    my $glob = $main::{'_<' . $file};
    return unless $glob;
    return *{$glob}{ARRAY};
}

## Methods called by the DB core - override in clients

sub init {}
sub poll {}
sub idle { 1;}
sub cleanup {}
sub notify_stopped {}
sub notify_resumed {}
sub notify_trace {}
sub notify_fork_parent {}
sub notify_fork_child {}
sub notify_program_terminated {}
sub notify_program_exit {}
sub notify_uncaught_exception {}

sub _do_each_client {
    my($method, @args) = @_;

    $_->$method(@args) foreach @attached_clients;
}

package DB;

use vars qw( %dbline @dbline );

our($stack_depth,
    $single,
    $signal,
    $trace,
    $debugger_disabled,
    $no_stopping,
    $step_over_depth,
    $ready,
    @saved,
    $usercontext,
    $in_debugger,
    $finished,
    $user_requested_exit,
    @AUTOLOAD_names,
    $sub,
    $uncaught_exception,
    %postpone_until_loaded,
);

BEGIN {
    $stack_depth    = 0;
    $single         = 0;
    $trace          = 0;
    $debugger_disabled = 0;
    $no_stopping    = 0;
    $step_over_depth = undef;
    $ready          = 0;
    @saved          = ();
    $usercontext    = '';
    $in_debugger    = 0;

    # Controlling program end of life
    $finished       = 0;
    $user_requested_exit = 0;

    # Remember AUTOLOAD sub names
    @AUTOLOAD_names = ();
}

sub save {
    # Save eval failure, command failure, extended OS error, output field
    # separator, input record separator, output record separator and
    # the warning setting.
    @saved = ( $@, $!, $^E, $,, $/, $\, $^W );

    $,  = "";      # output field separator is null string
    $/  = "\n";    # input record separator is newline
    $\  = "";      # output record separator is null string
    $^W = 0;       # warnings are off
}

sub restore {
    ( $@, $!, $^E, $,, $/, $\, $^W ) = @saved;
}

sub is_breakpoint {
    my($package, $filename, $line) = @_;

    if ($single and defined($step_over_depth) and $step_over_depth < $stack_depth) {
        # This is from a step-over
        $single = 0;
        return 0;
    }

    if ($single || $signal) {
        $single = $signal = 0;
        return 1;
    }

    local(*dbline)= $main::{'_<' . $filename};

    my $should_break = 0;
    my $breakpoint_key = Devel::Chitin::Breakpoint->type;
    if ($dbline{$line} && $dbline{$line}->{$breakpoint_key}) {
        my @delete;
        foreach my $condition ( @{ $dbline{$line}->{$breakpoint_key} }) {
            next if $condition->inactive;
            my $code = $condition->code;
            if ($code eq '1') {
                $should_break = 1;
            } else {
                ($should_break) = _eval_in_program_context($condition->code, 0);
            }
            push @delete, $condition if $condition->once;
        }
        $_->delete for @delete;
    }

    if ($should_break) {
        $single = $signal = 0;
    }
    return $should_break;
}


sub _parent_stack_location {
    my($package, $filename, $line) = caller(1);
    my(undef, undef, undef, $subname) = caller(2);
    $subname ||= 'MAIN';
    return ($package, $filename, $line, $subname);
}

BEGIN {
    # Code to get control when the debugged process forks
    *CORE::GLOBAL::fork = sub {
        my $pid = CORE::fork();
        return $pid unless $ready;

        my($package, $filename, $line, $subname) = _parent_stack_location();
        my $location = Devel::Chitin::Location->new(
            'package'   => $package,
            line        => $line,
            filename    => $filename,
            subroutine  => $subname,
        );

        my $notify = $pid ? 'notify_fork_parent' : 'notify_fork_child';
        Devel::Chitin::_do_each_client($notify, $location, $pid);
        return $pid;
    };
};

# Reporting uncaught exceptions back to the debugger clients
# inside the handler, note the value for $^S:
# undef - died while parsing something
# 1 - died while executing an eval
# 0 - Died not inside an eval
# We could re-throw the die if $^S is 1
$SIG{__DIE__} = sub {
    if (defined($^S) && $^S == 0) {
        $in_debugger = 1;
        my $exception = $_[0];
        # It's interesting to note that if we pass an arg to caller() to
        # find out the offending subroutine name, then the line reported
        # changes.  Instead of reporting the line the exception occurred
        # (which it correctly does with no args), it returns the line which
        # called the function which threw the exception.
        # We'll work around it by calling it twice
        my($package, $filename, $line, $subname) = _parent_stack_location();

        $uncaught_exception = Devel::Chitin::Exception->new(
            'package'   => $package,
            line        => $line,
            filename    => $filename,
            exception   => $exception,
            subroutine  => $subname,
        );
        # After we fall off the end, the interpreter will try and exit,
        # triggering the END block that calls DB::fake::at_exit()
    }
};


sub _execute_actions {
    my($filename, $line) = @_;
    local(*dbline) = $main::{'_<' . $filename};
    if ($dbline{$line} && $dbline{$line}->{action}) {
        my @delete;
        foreach my $action ( @{ $dbline{$line}->{action}} ) {
            next if $action->inactive;
            _eval_in_program_context($action->code, undef);
            push @delete, $action if $action->once;
        }
        $_->delete for @delete;
    }
}

sub DB {
    return if (!$ready or $debugger_disabled or $in_debugger);

    local($in_debugger) = 1;

    my($package, $filename, $line) = caller;
    my(undef, undef, undef, $subroutine) = caller(1);
    if ($package eq 'DB::fake') {
        $package = 'main';
    }
    $subroutine ||= 'MAIN';

    unless ($is_initialized) {
        $is_initialized = 1;
        Devel::Chitin::_do_each_client('init');
    }

    # set up the context for DB::eval, so it can properly execute
    # code on behalf of the user. We add the package in so that the
    # code is eval'ed in the proper package (not in the debugger!).
    save();
    local $usercontext =
        'no strict; no warnings; ($@, $!, $^E, $,, $/, $\, $^W) = @DB::saved;' . "package $package;";

    $current_location = Devel::Chitin::Location->new(
        'package'   => $package,
        filename    => $filename,
        line        => $line,
        subroutine  => $subroutine,
    );

    $_->notify_trace($current_location) foreach values(%trace_clients);

    _execute_actions($filename, $line);

    return if $no_stopping;

    if (! is_breakpoint($package, $filename, $line)) {
        return;
    }
    $step_over_depth = undef;

    Devel::Chitin::_do_each_client('notify_stopped', $current_location);

    STOPPED_LOOP:
    foreach (1) {

        while (my $e = shift @pending_eval) {
            _eval_in_program_context(@$e);
        }

        my $should_continue = 0;
        until ($should_continue) {
            my @ready_clients = grep { $_->poll($current_location) } @attached_clients;
            last STOPPED_LOOP unless (@ready_clients);
            do { $should_continue |= $_->idle($current_location) } foreach @ready_clients;
        }

        redo if ($finished || @pending_eval);
    }
    Devel::Chitin::_do_each_client('notify_resumed', $current_location);
    undef $current_location;
    Devel::Chitin::Stack::invalidate();
    restore();
}

BEGIN {
    my $sub_serial = 1;
    @Devel::Chitin::stack_serial = ( [ 'main::MAIN', $sub_serial++ ] );
    %Devel::Chitin::eval_serial = ();

    sub _allocate_sub_serial {
        $sub_serial++;
    }
}


sub sub {
    no strict 'refs';
    goto &$sub if (! $ready or index($sub, 'Devel::Chitin::StackTracker') == 0 or $debugger_disabled);

    local @AUTOLOAD_names = @AUTOLOAD_names;
    if (index($sub, '::AUTOLOAD', -10) >= 0) {
        my $caller_pkg = substr($sub, 0, length($sub)-8);
        my $caller_AUTOLOAD = ${ $caller_pkg . 'AUTOLOAD'};
        unshift @AUTOLOAD_names, $caller_AUTOLOAD;
    }
    my $stack_tracker;
    local @Devel::Chitin::stack_serial = @Devel::Chitin::stack_serial;
    unless ($in_debugger) {
        $stack_depth++;
        $stack_tracker = _new_stack_tracker(_allocate_sub_serial());

        push(@Devel::Chitin::stack_serial, [ $sub, $$stack_tracker]);
    }

    my @rv;
    if (wantarray) {
        @rv = &$sub;
    } elsif (defined wantarray) {
        $rv[0] = &$sub;
    } else {
        &$sub;
    }

    delete $Devel::Chitin::eval_serial{$$stack_tracker} if $stack_tracker;

    return wantarray ? @rv : $rv[0];
}

sub _new_stack_tracker {
    my $token = shift;
    my $self = bless \$token, 'Devel::Chitin::StackTracker';
}

sub Devel::Chitin::StackTracker::DESTROY {
    $stack_depth--;
    $single = 1 if (defined($step_over_depth) and $step_over_depth >= $stack_depth);
}



# This gets called after a require'd file is compiled, but before it's executed
# it's called as DB::postponed(*{"_<$filename"})
# We can use this to break on module load, for example.
# If $DB::postponed{$subname} exists, then this is called as
# DB::postponed($subname)
sub postponed {
    my($filename) = ($_[0] =~ m/_\<(.*)$/);

    if (my $actions = delete $postpone_until_loaded{$filename}) {
        $_->($filename) foreach @$actions;
    }
}

END {
    $trace = 0;

    return if $debugger_disabled;

    $single=0;
    $in_debugger = 1;

    eval {
        Devel::Chitin::_do_each_client('notify_uncaught_exception', $uncaught_exception) if $uncaught_exception;

        if ($user_requested_exit) {
            Devel::Chitin::_do_each_client('notify_program_exit');
        } else {
            Devel::Chitin::_do_each_client('notify_program_terminated', $?);
            $finished = 1;
            # These two will trigger DB::DB and the event loop
            $in_debugger = 0;
            $single=1;
            Devel::Chitin::exiting::at_exit();
        }
    }
}

package Devel::Chitin::exiting;
sub at_exit {
    1;
}

package DB;
BEGIN { $DB::ready = 1; }

1;

__END__

=pod

=head1 NAME

Devel::Chitin - Programmatic interface to the Perl debugging API

=head1 SYNOPSIS

  package CLIENT;
  use base 'Devel::Chitin';

  # These inherited methods can be called by the client class
  CLIENT->attach();             # Register with the debugging system
  CLIENT->detach();             # Un-register with the debugging system
  CLIENT->step();               # single-step into subs
  CLIENT->stepover();           # single-step over subs
  CLIENT->stepout();            # Return from the current sub, then stop
  CLIENT->continue();           # Run until the next breakpoint
  CLIENT->trace([$flag]);       # Get/set the trace flag
  CLIENT->disable_debugger();   # Deactivate the debugging system
  CLIENT->is_loaded($file);     # Return true if the file is loaded
  CLIENT->loaded_files();       # Return a list of loaded file names
  CLIENT->postpone($file, $subref);     # Run $subref->() when $file is loaded
  CLIENT->is_breakable($file, $line);   # Return true if the line is executable
  CLIENT->stack();              # Return Devel::Chitin::Stack
  CLIENT->current_location();   # Where is the program stopped at?

  # These methods are called by the debugging system at the appropriate time.
  # Base-class methods do nothing.  These methods must not block.
  CLIENT->init();                       # Called when the debugging system is ready
  CLIENT->poll($location);              # Return true if there is user input
  CLIENT->idle($location);              # Handle user interaction (can block)
  CLIENT->notify_trace($location);      # Called on each executable statement
  CLIENT->notify_stopped($location);    # Called when a break has occured
  CLIENT->notify_resumed($location);    # Called before the program gets control after a break
  CLIENT->notify_fork_parent($location,$pid);   # Called after fork() in parent
  CLIENT->notify_fork_child($location);         # Called after fork() in child
  CLIENT->notify_program_terminated($?);    # Called as the program is finishing 
  CLIENT->notify_program_exit();            # Called as the program is exiting
  CLIENT->notify_uncaught_exception($exc);  # Called after an uncaught exception

=head1 DESCRIPTION

This class exposes the Perl debugging facilities as an API useful for
implementing debuggers, tracers, profilers, etc so they can all benefit from
common code.

Devel::Chitin is not a usable debugger per se.  It has no mechanism for interacting
with a user such as reading command input or printing results.  Instead,
clients of this API may call methods to inspect the debugged program state.
The debugger core calls methods on clients when certain events occur, such
as when the program is stopped by breakpoint or when the program exits.
Multiple clients can attach themselves to Devel::Chitin simultaneously within
the same debugged program.

=head1 CONSTRUCTOR

This class does not supply a constructor.  Clients wishing to use this API
must inherit from this class and call the C<attach> method.  They may use
whatever mechanism they wish to implement their object or class.

=head1 API Methods

These methods are provided by the debugging API and may be called as inherited
methods by clients.

=over 4

=item CLIENT->attach()

Attaches a client to the debugging API.  May be called as a class or instance
method.  When later client methods are called by the debugging API, the
same invocant will be used.

=item CLIENT->detach()

Removes a client from the debugging API.  The invocant must match a previous
C<attach> call.

=item CLIENT->trace([1 | 0])

Get or set the trace flag.  If trace is on, the client will get notified
before every executable statement by having its C<notify_trace> method called.

=item CLIENT->disable_debugger()

Turn off the debugging system.  The debugged program will continue normally.
The debugger system will not be triggered afterward.

=item CLIENT->postpone($file, $subref)

Causes C<$subref> to be called when $file is loaded.  If $file is already
loaded, then $subref will be called immediately.


=back

=head2 Program control methods

=over 4

=item CLIENT->step()

Single-step the next statement in the debugged program.  If the next statement
is a subroutine call, the debugger will stop on its first executable statement.

=item CLIENT->stepover()

Single-step the next statement in the debugged program.  If the next statement
is a subroutine call, the debugger will stop on its first executable statement
after that subroutine call returns.

=item CLIENT->stepout()

Continue running the debugged program until the current subroutine returns
or until the next breakpoint, whichever comes first.

=item CLIENT->continue()

Continue running the debugged program until the next breakpoint.

=item CLIENT->user_requested_exit()

Sets a flag that indicates the program should completely exit after the
debugged program ends.  Normally, the debugger will regain control after the
program ends.

=item CLIENT->eval($string, $wantarray, $coderef);

Evaluate the given string in the context of the most recent stack frame of
the program being debugged.  Because of the limitations of Perl's debugging
hooks, this function does not return the value directly.  Instead, the
caller must cede control back to the debugger system and the eval will be
done before the next statement in the program being debugged.  If the
debugged program is currently stopped at a breakpoint, then the eval will be
done before resuming.

The result is delivered by calling the given $coderef with two arguments:
the $result and $exception.  If $wantarray was true, then the result will
be an arrayref.

=item CLIENT->eval_at($string [, $level]);

Evaluate the given string in the context of the program being debugged.  If
$level is omitted, the string is run in the context of the most recent stack
frame of the debugged program.  Otherwise, $level is the number of stack
frames before the most recent to evaluate the code in.  Negative numbers are
treated as 0.  eval_at returns a list of two items, the result and exception.

This method requires the PadWalker module.

This method is not yet implemented.

=item CLIENT->get_var_at_level($string, $level);

Return the value of the given variable expression.  $level is the stack level
in the context of the debugged program; 0 is the most recent level.  $string
is the name of the variable to inspect, including the sigil.  This method
handles some more complicated expressions such array and hash elements and
slices.

This method is temporary, until eval_at() is implemented.

=back

=head2 Informational methods

=over 4

=item CLIENT->is_loaded($file)

Return true if the file is loaded

=item CLIENT->loaded_files()

Return a list of loaded file names

=item CLIENT->is_breakable($file, $line)

Return true if the line has an executable statement.  Only lines with executable
statements may have breakpoints.  In particular, line containing only comments,
whitespace or block delimiters are typically not breakable.

=item CLIENT->subroutine_location($subroutine)

Return a L<Devel::Chitin::SubroutineLocation> instance for where the
named subroutine was defined.  C<$subroutine> should be fully qualified
including the package name.

If the named function does not exist, it returns undef.

=item CLIENT->stack()

Return an instance of L<Devel::Chitin::Stack>.  This object represents the
execution/call stack of the debugged program.

=item CLIENT->current_location()

Return an instance of L<Devel::Chitin::Location> representing the currently
stopped location in the debugged program.  This method returns undef if
called when the debugged program is actively running.

=item CLIENT->file_source($filename)

Return a list of strings containing the source code for a loaded file.

=back

=head2 Breakpoints and Actions

See L<Devel::Chitin::Actionable> for documentation on setting breakpoints
and actions.

=head2 CLIENT METHODS

These methods exist in the base class, but only as empty stubs.  They are
called at the appropriate time by the debugging system.  Clients may provide
their own implementation.

With the exception of C<idle>, these client-provided methods must not block
so that other clients may get called.

=over 4

=item CLIENT->init()

Called before the first breakpoint, usually before the first executable
statement in the debugged program.  Its return value is ignored

=item CLIENT->poll($location)

Called when the debugger is stopped on a line.  This method should return
true to indicate that it wants its C<idle> method called.

=item CLIENT->idle($location)

Called when the client can block, to accept and process user input, for
example.  This method should return true to indicate to the debugger system
that it has finished processing, and that it is OK to continue the debugged
program.  The loop around calls to C<idle> will stop when all clients return
true.

=item CLIENT->notify_trace($location)

If a client has turned on the trace flag, this method will be called before
each executable statement.  The return value is ignored.  $location is an
instance of L<Devel::Chitin::Location> indicating the next statement to be
executed in the debugged program.

notify_trace() will be called only on clients that have requested tracing by
calling CLIENT->trace(1).

=item CLIENT->notify_stopped($location)

This method is called when a breakpoint has occurred.  Its return value is
ignored.

=item CLIENT->notify_resumed($location)

This method is called after a breakpoint, after any calls to C<idle>, and
just before the debugged program resumes execution.  The return value is
ignored.

=item CLIENT->notify_fork_parent($location, $pid)

This method is called immediately after the debugged program calls fork()
in the context of the parent process.  C<$pid> is the child process ID
created by the fork.  The return value is ignored.

Note that the $location will be the first executable statement _after_ the
fork() in the parent process.

=item CLIENT->notify_fork_child($location)

This method is called immediately after the debugged program calls fork()
in the context of the child process.  The return value is ignored.

Note that the $location will be the first executable statement _after_ the
fork() in the parent process.

=item CLIENT->notify_program_terminated($?)

This method is called after the last executable statement in the debugged
program.  After all clients are notified, the debugger system emulates
one final breakpoint inside a function called C<at_exit> and the program
remains running, though stopped.

=item CLIENT->notify_program_exit()

If the a client has requested that the program terminate completely by calling
CLIENT->user_requested_exit(), then this method will be called during the
debugger's END block as the interpreter is cleaning up.

=item CLIENT->notify_uncaught_exception($exception)

The debugger system installs a __DIE__ handler to trap exceptions that are
not otherwise handled by the debugged program.  When an uncaught exception
occurs, this method is called.  $exception is an instance of
L<Devel::Chitin::Exception>.

=back

=head1 BUGS

As this is an extremely early release, this API should be considered
experimental.  It was developed to extract the debugger-specific code
from Devel::hdb.  I encourage others to make suggestions and submit bug
reports so we can converge on a usable API quickly.

=head1 SEE ALSO

L<Devel::Chitin::Location>, L<Devel::Chitin::Exception>,
L<Devel::Chitin::Stack>, L<Devel::Chitin::Actionable>,
L<Devel::Chitin::GetVarAtLevel>

The API for this module was inspired by L<DB>

=head1 AUTHOR

Anthony Brummett <brummett@cpan.org>

=head1 COPYRIGHT

Copyright 2014, Anthony Brummett.  This module is free software. It may
be used, redistributed and/or modified under the same terms as Perl itself.

