use strict;
use warnings;

use Devel::Chitin::OpTree;
use Devel::Chitin::Location;

use Test2::Tools::Basic;
use Test2::Tools::Compare;
use Test2::Tools::Subtest qw(subtest_buffered);
sub subtest($&);
*subtest = \&Test2::Tools::Subtest::subtest_buffered;

use Fcntl qw(:flock :DEFAULT SEEK_SET SEEK_CUR SEEK_END);
use POSIX qw(:sys_wait_h);
use Socket;
use Scalar::Util qw(blessed refaddr);

plan tests => 21;

subtest operators => sub {
    _run_tests(
        undef_op => join("\n",  q(my $a = undef;),
                                q(undef($a);),
                                q(my(@a, %a);),
                                q(undef($a[1]);),
                                q(undef($a{'foo'});),
                                q(undef(@a);),
                                q(undef(%a);),
                                q(undef(&some::function::name))),
        defined_op => join("\n",q(my $a;),
                                q($a = defined($a);),
                                q($a = defined())),
        scalar_op => join("\n", q(my($a, @a);),
                                q($a = scalar(@a);),
                                q($a = scalar($a))),
        add_op => join("\n",    q(my($a, $b);),
                                q($a = $a + $b;),
                                q($b = $a + $b + 1)),
        sub_op => join("\n",    q(my($a, $b);),
                                q($a = $a - $b;),
                                q($b = $a - $b - 1)),
        mul_op => join("\n",    q(my($a, $b);),
                                q($a = $a * $b;),
                                q($b = $a * $b * 2)),
        div_op => join("\n",    q(my($a, $b);),
                                q($a = $a / $b;),
                                q($b = $a / $b / 2)),
        mod_op => join("\n",    q(my($a, $b);),
                                q($a = $a % $b;),
                                q($b = $a % $b % 2)),
        preinc_op => join("\n", q(my $a = 4;),
                                q(my $b = ++$a)),
        postinc_op => join("\n",q(my $a = 4;),
                                q(my $b = $a++)),
        bin_negate => join("\n",q(my $a = 3;),
                                q(my $b = ~$a;),
                                q($a = ~$b)),
        deref_op => join("\n",  q(my $a = 1;),
                                q(our $b = 2;),
                                q($a = $a->{'foo'};),
                                q($a = $b->{'foo'}->[2];),
                                q($a = @{ $a->{'foo'}->[3]->{'bar'} };),
                                q($a = %{ $b->[2]->{'foo'}->[4] };),
                                q($a = ${ $a->{'foo'}->[5]->{'bar'} };),
                                q($a = *{ $b->[$a]->{'foo'}->[5] };),
                                q($a = $$a;),
                                q($b = $$b)),
        pow_op => join("\n",    q(my $a;),
                                q($a = 3 ** $a)),
        log_negate => join("\n",q(my $a = 1;),
                                q($a = !$a)),
        repeat => join("\n",    q(my $a;),
                                q($a = $a x 10;),
                                q(my @a = (1, 2, 3) x $a)),
        shift_left => join("\n",q(my $a;),
                                q($a = $a << 1;),
                                q($a = $a << $a)),
        shift_right => join("\n",q(my $a;),
                                q($a = $a >> 1;),
                                q($a = $a >> $a)),
        bit_and => join("\n",   q(my $a;),
                                q($a = $a & 1;),
                                q(my $b = $a & 3 & $a)),
        bit_or => join("\n",    q(my $a;),
                                q($a = $a | 1;),
                                q(my $b = $a | 3 | $a)),
        bit_xor => join("\n",   q(my $a;),
                                q($a = $a ^ 1)),
        log_and => join("\n",   q(my $a = 1;),
                                q(our $b = 2;),
                                q($a = $a && $b;),
                                q($b = $b && $a)),
        log_or => join("\n",    q(my $a = 2;),
                                q(our $b = 1;),
                                q($a = $a || $b;),
                                q($b = $b || $a)),
        log_xor => no_warnings('void'),
                   join("\n",   q(my $a = 1;),
                                q(our $b = 2;),
                                q($a = $a xor $b;),
                                q($b = $b xor $a)),
        assignment_ops => join("\n",    q(my $a = 1;),
                                        q(our $b = 2;),
                                        q($a += $b + 1;),
                                        q($b -= $b - 1;),
                                        q($a *= $b + 1;),
                                        q($a /= $b - 1;),
                                        q($a .= $b . 'hello';),
                                        q($a **= $b + 1;),
                                        q($a &= $b;),
                                        q($a &&= $b;),
                                        q($b ||= $a;),
                                        q($b |= 1;),
                                        q($a ^= $b;),
                                        q($a <<= $b;),
                                        q($b >>= $a)),
        conditional_op => join("\n",    q(my($a, $b);),
                                        q($a = $b ? $a : 1)),
        flip_flop => join("\n",     q(my($a, $b);),
                                    q($a = $a .. $b;),
                                    q($a = $a ... $b)),
        references => join("\n",    q(my($scalar, @list, %hash);),
                                    q(my $a = \$scalar;),
                                    q($a = \\@list;),
                                    q($a = \\(@list, 1, 2);),
                                    q($a = \\%hash;),
                                    q($a = \\*scalar_assignment;),
                                    q($a = \\&scalar_assignment;),
                                    q($a = sub { my $inner = 1 };),
                                    q($a = sub {),
                                   qq(\tfirst_thing();),
                                   qq(\tsecond_thing()),
                                    q(})),
    );
};

subtest 'program flow' => sub {
    _run_tests(
        caller_fcn => join("\n",    q(my @info = caller();),
                                    q(my $package = caller();),
                                    q(@info = caller(1);),
                                    q($package = caller(2))),
        exit_fcn => join("\n",      q(exit(123);),
                                    q(exit($a);),
                                    q(exit())),
        do_file =>  join("\n",      q(my $val = do 'some_file.pl';),  # like require
                                    q($val = do $val)),
        do_block => join("\n",      q[my $val = do { sub_name() };],
                                    q[$val = do {],
                                   qq[\tfirst_thing();],
                                   qq[\tsecond_thing(1);],
                                   qq[\tthird_thing(1, 2, 3)],
                                    q[};],
                                    q[print 'done']),
        package_declaration => join("\n",   q(my $a = 1;),
                                            q(package Foo;),
                                            q(my $b = 2;),
                                            q(package Bar;),
                                            q(my $c = 3)),
        require_file => join("\n",      q(require 'file.pl';),
                                        q(my $file;),
                                        q(require $file)),
        require_module =>   q(require Some::Module),
        require_version =>  q(require v5.8.7),
        wantarray_keyword =>            q(my $wa = wantarray),
        return_keyword =>               q(return(1, 2, 3)),
        dump_keyword => no_warnings('misc'),
                        join("\n",      q(dump;),
                                        q(dump DUMP_LABEL)),
        goto_label => join("\n",        q(LABEL:),
                                        q(goto LABEL;),
                                        q(my $expr;),
                                        q(goto $expr)),
        goto_sub => join("\n",      q(goto &Some::sub;),
                                    q(goto sub { 1 })),
        if_statement => join("\n",  q(my $a;),
                                    q(if ($a) {),
                                   qq(\tprint 'hi'),
                                    q(}),
                                    q(if ($a) {),
                                   qq(\tprint 'hello';),
                                   qq(\tworld()),
                                    q(}),
                                    q(print 'done')),
        if_else => join("\n",       q(my $a;),
                                    q(if ($a) {),
                                   qq(\tprint 'hi'),
                                    q(} else {),
                                   qq(\tprint 'hello';),
                                   qq(\tworld()),
                                    q(}),
                                    q(print 'done')),
        elsif_else_chain => join("\n",  q(my $a;),
                                        q(if ($a < 1) {),
                                       qq(\tprint 'less'),
                                        q(} elsif ($a > 1) {),
                                       qq(\tprint 'more'),
                                        q(} elsif (defined($a)) {),
                                           qq(\tprint 'zero'),
                                        q(} else {),
                                       qq(\tprint 'undef'),
                                        q(}),
                                        q(print 'done')),
        elsif_chain => join("\n",   q(my $a;),
                                    q(if ($a < 1) {),
                                   qq(\tprint 'less'),
                                    q(} elsif ($a > 1) {),
                                   qq(\tprint 'more'),
                                    q(} elsif (defined($a)) {),
                                       qq(\tprint 'zero'),
                                    q(}),
                                    q(print 'done')),
        unless_statement => join("\n",  q(my $a;),
                                        q(unless ($a) {),
                                       qq(\tprint 'hi'),
                                        q(})),
        postfix_if => join("\n",    q(my $a;),
                                    q(print 'hi' if $a;),
                                    q(print 'done')),
        postfix_unless => join("\n",q(my $a;),
                                    q(print 'hi' unless $a;),
                                    q(print 'done')),
        while_loop => join("\n",    q(my($a, $b);),
                                    q(while ($a && $b) {),
                                   qq(\tprint 'hi';),
                                   qq(\tprint 'there'),
                                    q(}),
                                    q(while ($a) {),
                                   qq(\tprint 'hi'),
                                    q(})),
        while_continue => join("\n",q(my $a;),
                                    q(while ($a) {),
                                   qq(\tprint 'hi'),
                                    q(} continue {),
                                   qq(\tprint 'continued';),
                                   qq(\tprint 'here'),
                                    q(}),
                                    q(print 'done')),
        until_loop => join("\n",    q(my $a;),
                                    q(until ($a && $b) {),
                                   qq(\tprint 'hi'),
                                    q(}),
                                    q(print 'done')),
        postfix_while => join("\n", q(my $a;),
                                    q(++$a while ($a < 5);),
                                    q(print 'hi' while ($a < 5);),
                                    q(do {),
                                   qq(\t++\$a;),
                                   qq(\tprint 'hi'),
                                    q(} while ($a < 5);),
                                    q(print 'done')),
        postfix_until => join("\n", q(my $a;),
                                    q(++$a until ($a < 5);),
                                    q(print 'hi' until ($a < 5);),
                                    q(do {),
                                   qq(\t++\$a;),
                                   qq(\tprint 'hi'),
                                    q(} until ($a < 5);),
                                    q(print 'done')),
        for_loop => join("\n",      q(for (my $a = 0; $a < 10; ++$a) {),
                                   qq(\tprint 'hi';),
                                   qq(\tprint 'there'),
                                    q(}),
                                    q(print 'done')),
        foreach_loop => join("\n",  q(my @a;),
                                    q(foreach my $a (1, 2, @a) {),
                                   qq(\tprint 'hi';),
                                   qq(\tprint 'there'),
                                    q(}),
                                    q(foreach our $a (@a) {),
                                   qq(\tprint 'hi';),
                                   qq(\tprint 'there'),
                                    q(}),
                                    q(foreach my $a (reverse(@a)) {),
                                   qq(\tprint 'hi';),
                                   qq(\tprint 'there'),
                                    q(})),
        foreach_range => join("\n", q(foreach my $a (1 .. 10) {),
                                   qq(\tprint 'hi';),
                                   qq(\tprint 'there'),
                                    q(}),
                                    q(print 'done')),
        postfix_foreach => join("\n",   q(my @a;),
                                        q(print() foreach (@a);),
                                        q(print 'done')),
        next_last_redo => join("\n",q(THE_LABEL:),
                                    q(foreach $_ (1, 2, 3) {),
                                   qq(\tnext;),
                                   qq(\tlast THE_LABEL;),
                                   qq(\tredo),
                                    q(})),
    );
};

#subtest 'misc stuff' => sub {
#    _run_tests(
#        # lock prototype reset
#    );
#};

subtest process => sub {
    _run_tests(
        alarm_fcn => q(alarm(4)),
        exec_fcn => no_warnings('exec'),
                    join("\n",  q(my $rv = exec('/bin/echo', 'hi', 'there');),
                                q($rv = exec('/bin/echo | cat');),
                                q($rv = exec { '/bin/echo' } ('hi', 'there');),
                                q(my $a = exec $rv ('hi', 'there'))),
        system_fcn => join("\n",q(my $rv = system('/bin/echo', 'hi', 'there');),
                                q($rv = system('/bin/echo | cat');),
                                q($rv = system { '/bin/echo' } ('hi', 'there');),
                                q(my $a = system $rv ('hi', 'there'))),
        fork_fcn => join("\n",  q(fork();),
                                q(my $a = fork())),
        getpgrp_fcn => join("\n",   q(my $a = getpgrp(0);),
                                    q($a = getpgrp(1234))),
        getppid_fcn => join("\n",   q(my $a = getppid();),
                                    q(getppid())),
        kill_fcn => join("\n",  q(my $rv = kill(0);),
                                q($rv = kill('HUP', $$);),
                                q($rv = kill(-9, 1, 2, 3);),
                                q($rv = kill('TERM', -1, -2, -3))),
        pipe_fcn => join("\n",  q(my($a, $b);),
                                q(pipe($a, $b))),
        readpipe_fcn => join("\n",  q(my $rv = `/bin/echo 'hi','there'`;),
                                    q($rv = `$rv`;),
                                    q($rv = readpipe('/bin/echo "hi","there"');),
                                    q($rv = readpipe($rv);),
                                    q($rv = readpipe(foo()))),
        sleep_fcn => join("\n",     q(my $a = sleep();),
                                    q($a = sleep(10))),
        times_fcn => join("\n",     q(my @a = times();),
                                    q(my $a = times())),
        wait_fcn => join("\n",      q(my $a = wait();),
                                    q(wait())),
        getpriority_fcn => join("\n",   q(my $a = getpriority(1, 2);),
                                        q($a = getpriority(0, 0))),
        setpriority_fcn => join("\n",   q($a = setpriority(1, 2, 3);),
                                        q($a = setpriority(0, 0, -2))),
        setpgrp_fcn => join("\n",   q(my $a = setpgrp();),
                                    q($a = setpgrp(0, 0);),
                                    q($a = setpgrp(9, 10))),
    );
};

subtest 'process waitpid' => sub {
    plan skip_all => q(WNOHANG isn't defined on Windows) if $^O eq 'MSWin32';
    _run_tests(
        waitpid_fcn => join("\n",   q(my $a = waitpid(123, WNOHANG | WUNTRACED);),
                                    q($a = waitpid($a, 0))),
    );
};

subtest classes => sub {
    _run_tests(
        bless_fcn => join("\n", q(my $obj = bless({}, 'Some::Package');),
                                q($obj = bless([]))),
        ref_fcn => join("\n",   q(my $r = ref(1);),
                                q($r = ref($r);),
                                q($r = ref())),
        tie_fcn => join("\n",   q(my $a;),
                                q(my $r = tie($a, 'Some::Package', 1, 2, 3);),
                                q($r = tie($r, 'Other::Package', $a))),
        tied_fcn => join("\n",  q(my $a;),
                                q(my $r = tied($a))),
        untie_fcn => join("\n", q(my $a;),
                                q(untie($a))),
    );
};

subtest sockets => sub {
    _run_tests(
        accept_fcn => join("\n",q(my($a, $b);),
                                q(my $rv = accept($a, $b))),
        bind_fcn => join("\n",  q(my($sock, $name);),
                                q(my $rv = bind($sock, $name))),
        connect_fcn => join("\n",   q(my($sock, $name);),
                                    q(my $rv = connect($sock, $name))),
        listen_fcn => join("\n",    q(my $sock;),
                                    q(my $rv = listen($sock, 5))),
        getpeername_fcn => join("\n",   q(my $sock;),
                                        q(my $rv = getpeername($sock))),
        getsockname_fcn => join("\n",   q(my $sock;),
                                        q(my $rv = getsockname($sock))),
        getsockopt_fcn => join("\n",    q(my $sock;),
                                        q(my $rv = getsockopt($sock, 1, 2))),
        setsockopt_fcn => join("\n",    q(my $sock;),
                                        q(my $rv = setsockopt($sock, 1, 2, 3))),
        send_fcn => join("\n",  q(my($sock, $dest);),
                                q(my $rv = send($sock, 'themessage', 1);),
                                q($rv = send($sock, $rv, 1, $dest))),
        recv_fcn => join("\n",  q(my($sock, $buf);),
                                q(my $rv = recv($sock, $buf, 123, 456))),
        shutdown_fcn => join("\n",  q(my $sock;),
                                    q(my $rv = shutdown($sock, 2))),
        socket_fcn => join("\n",    q(my $sock;),
                                    q(my $rv = socket(SOCK, PF_INET, SOCK_STREAM, 3);),
                                    q($rv = socket(*SOCK, PF_UNIX, SOCK_DGRAM, 2);),
                                    q($rv = socket($sock, PF_INET, SOCK_RAW, 1))),
        socketpair_fcn => join("\n",q(my($a, $b);),
                                    q(my $rv = socketpair(SOCK, $a, AF_UNIX, SOCK_STREAM, PF_UNSPEC);),
                                    q($rv = socketpair($b, *SOCK, AF_INET6, SOCK_DGRAM, 1234))),
    );
};

subtest 'sysV ipc' => sub {
    _run_tests(
        msgctl_fcn => join("\n",    q(my $a;),
                                    q(my $rv = msgctl(1, 2, $a))),
        msgget_fcn => join("\n",    q(my $a;),
                                    q(my $rv = msgget($a, 0))),
        msgsnd_fcn => join("\n",    q(my $a;),
                                    q(my $rv = msgsnd(1, $a, 0))),
        msgrecv_fcn => join("\n",   q(my $a;),
                                    q(my $rv = msgrecv(1, $a, 1, 2, 3))),
        semctl_fcn => join("\n",    q(my $a;),
                                    q(my $rv = semctl(1, $a, 2, 3))),
        semget_fcn => join("\n",    q(my $a;),
                                    q(my $rv = semget(1, $a, 2))),
        semop_fcn => join("\n",     q(my $a;),
                                    q(my $rv = semop(1, $a))),
        shmctl_fcn => join("\n",    q(my $a;),
                                    q(my $rv = shmctl(1, $a, 2))),
        shmget_fcn => join("\n",    q(my $a;),
                                    q(my $rv = shmget(1, $a, 2))),
        shmread_fcn => join("\n",   q(my $a;),
                                    q(my $rv = shmread(1, $a, 2, 3))),
        shmwrite_fcn => join("\n",  q(my $a;),
                                    q(my $rv = shmwrite(1, $a, 2, 3))),
    );
};

subtest time => sub {
    _run_tests(
        localtime_fcn => join("\n", q(my $a = localtime();),
                                    q(my @a = localtime(12345))),
        gmtime_fcn => join("\n",    q(my $a = gmtime();),
                                    q(my @a = gmtime(12345))),
        time_fcn => join("\n",      q(my $a = time();),
                                    q(time())),
    );
};

subtest 'perl-5.10.1' => sub {
    _run_tests(
        requires_version(v5.10.1),
        unpack_one_arg => join("\n", q($a = unpack($a))),
        mkdir_no_args => join("\n",  q(mkdir())),
        say_fcn => join("\n",   q(my $a = say();),
                                q(say('foo bar', 'baz', "\n");),
                                q(say F ('foo bar', 'baz', "\n");),
                                q(say "Hello\n";),
                                q(say F "Hello\n";),
                                q(my $f;),
                                q(say { $f } ('foo bar', 'baz', "\n");),
                                q(say { *$f } ('foo bar', 'baz', "\n"))),
        stacked_file_tests =>   q(-r -x -d '/tmp'),
        defined_or => join("\n",q(my $a;),
                                q(my $rv = $a // 1;),
                                q($a //= 4)),
    );
};

subtest 'given-when-5.10.1' => sub {
    _run_tests(
        requires_version(v5.10.1),
        excludes_only_version(v5.27.7),
        given_when_5_10 => join("\n",
                                q(my $a;),
                                q(given ($a) {),
                               qq(\twhen (1) { print 'one' }),
                               qq(\twhen (2) {),
                               qq(\t\tprint 'two';),
                               qq(\t\tprint 'more';),
                               qq(\t\tcontinue),
                               qq(\t}),
                               qq(\twhen (3) {),
                               qq(\t\tprint 'three';),
                               qq(\t\tbreak;),
                               qq(\t\tprint 'will not run'),
                               qq(\t}),
                               qq(\tdefault { print 'something else' }),
                                q(})),
    );
};

# from the reverted given/whereso/whereis from 5.27.7
#subtest 'given-when-5.27.7' => sub {
#    _run_tests(
#        requires_version(v5.27.7),
#        given_when_5_27 => join("\n",
#                              q(my $a;),
#                              q(given ($a) {),
#                             qq(\twhereso (m/abc/) {),
#                             qq(\t\tprint 'abc';),
#                             qq(\t\tprint 'ABC'),
#                             qq(\t}),
#                             qq(\twhereso (m/def/) {),
#                             qq(\t\tprint 'def'),
#                             qq(\t}),
#                             qq(\tprint 'ghi' whereso (m/ghi/);),
#                             qq(\twhereis ('123') {),
#                             qq(\t\tprint '123'),
#                             qq(\t}),
#                             qq(\tprint '456' whereis (456);),
#                             qq(\tprint 'default case'),
#                             qq(})),
#    );
#};

subtest 'perl-5.12' => sub {
    _run_tests(
        requires_version(v5.12.0),
        keys_array => join("\n",    q(my @a = (1, 2, 3, 4);),
                                    q(keys(@a))),
        values_array => join("\n",  q(my @a = (1, 2, 3, 4);),
                                    q(values(@a))),
        each_array => join("\n",    q(my @a = (1, 2, 3, 4);),
                                    q(each(@a))),
    );
};

subtest 'perl-5.14' => sub {
    _run_tests(
        requires_version(v5.14.0),
        tr_r_flag => no_warnings('misc'),
                     join("\n",     q(my $a;),
                                    q($a = tr/$a/zyxw/cdsr)),
    );
};

subtest '5.14 experimental ref ops' => sub {
    _run_tests(
        requires_version(v5.14.0),
        excludes_version(v5.24.0),
        no_warnings(),
        keys_ref => join("\n",  q(my $h = {1 => 2, 3 => 4};),
                                q(keys($h);),
                                q(my $a = [1, 2, 3];),
                                q(keys($a))),
        each_ref => join("\n",  q(my $h = {1 => 2, 3 => 4};),
                                q(my $v = each($h);),
                                q(my $a = [1, 2, 3];),
                                q(each($a))),
        values_ref => join("\n",q(my $h = {1 => 2, 3 => 4};),
                                q(values($h);),
                                q(my $a = [1, 2, 3];),
                                q(values($a))),
        pop_ref => join("\n",   q(my $a = [1, 2, 3];),
                                q(pop($a))),
        push_ref => join("\n",  q(my $a = [1, 2, 3];),
                                q(push($a, 1))),
        shift_ref => join("\n", q(my $a = [1, 2, 3];),
                                q(shift($a))),
        unshift_ref => join("\n",   q(my $a = [1, 2, 3];),
                                    q(unshift($a, 1))),
        splice_ref => join("\n",    q(my $a = [1, 2, 3];),
                                    q(splice($a, 2, 3, 4))),
    );
};

subtest 'perl-5.16' => sub {
    _run_tests(
        requires_version(v5.16.0),
        foldcase => join("\n",  q(my $a = 'aAbBcC';),
                                q($a = fc($a);),
                                q(fc($a);),
                                q($a = fc();),
                                q(print qq(ab\F$a\E))),
    );
};

subtest 'perl-5.18' => sub {
    _run_tests(
        requires_version(v5.18.0),
        dump_expr => no_warnings('misc'),
                     join("\n", q(my $expr;),
                                q(dump $expr;),
                                q(dump 'foo' . $expr)),
        next_last_redo_expr => join("\n",   q(foreach my $a (1, 2) {),
                                           qq(\tnext \$a;),
                                           qq(\tlast 'foo' . \$a;),
                                           qq(\tredo \$a + \$a),
                                            q(})),
    );
};

subtest 'perl-5.20 incompatibilities' => sub {
    _run_tests(
        excludes_version(v5.20.0),
        do_sub =>   q(my $val = do some_sub_name(1, 2)), # deprecated sub call
    );
};

subtest 'perl-5.20' => sub {
    _run_tests(
        requires_version(v5.20.0),
        hash_slice_hash => join("\n",   q(my(%h, $h);),
                                        q(my %slice = %h{'key1', 'key2'};),
                                        q(%slice = %$h{'key1', 'key2'})),
        hash_slice_array=> join("\n",   q(my(@a, $a);),
                                        q(my %slice = %a[1, 2];),
                                        q(%slice = %$a[1, 2])),
        # although there's no way to distinguish @$a from $a->@*, it checks whether
        # the "postderef" feature is on and uses it if it is
        # commented out for now because it messed with the two slice tests above
#        postderef => join("\n",         q(my $a = 1;),
#                                        q(our $b = 2;),
#                                        q($a->[1]->$*;),
#                                        q($a->{'one'}->@*;),
#                                        q($b->[1]->$#*;),
#                                        q($b->{'one'}->%*;),
#                                        q($a->[1]->&*;),
#                                        q($a->[1]->**;)),
# postfix dereferencing
# $a->@*
# $a->@[1,2]
# $a->%{'one', 'two'}
# check warning bits for "use experimental 'postderef'
    );
};

subtest 'perl-5.22 differences' => sub {
    _run_tests(
        excludes_version(v5.22.0),
        readline_with_brackets => join("\n",    q(my $fh;),
                                                q(my $line = <$fh>;),
                                                q(my @lines = <$fh>)),
        hash_key_assignment => join("\n",   q(my(%a, $a);),
                                            q($a{key} = 1;),
                                            q($a{'key'} = 1;),
                                            q($a{'1'} = 1;),
                                            q($a->{key} = 1;),
                                            q($a->{'key'} = 1;),
                                            q($a->{'1'} = 1)),
    );
};

subtest 'perl-5.22' => sub {
    _run_tests(
        requires_version(v5.22.0),
        use_feature('bitwise'),
        use_feature('refaliasing'),
        string_bitwise  => join("\n",   q(my($a, $b);),
                                        q($a = $a &. $b;),
                                        q($a &.= $b;),
                                        q($a = $a |. 'str';),
                                        q($a |.= 'str';),
                                        q($a = $a ^. 1;),
                                        q($a ^.= $b;),
                                        q($a = ~.$a)),
        regex_n_flag => join("\n",  q(my $str;),
                                    q($str =~ m/(hi|hello)/n)),
        list_repeat => join("\n",   q(my @a = (1, 2) x 5)),
        ref_alias => join("\n",     q(my($a, $b) = (1, 2);),
                                    q(\$a = \$b;),
                                    q[\($a) = \$b;],
                                    q(our @array = (1, 2);),
                                    q(\$array[1] = \$a;),
                                    q(my %hash = (1, 1);),
                                    q(\$hash{'1'} = \$b)),
        listref_alias => join("\n", q(my($a, $b, @array);),
                                    q(\@array[1, 2] = (\$a, \$b);),
                                    q[\(@array) = (\$a, \$b)]),
        alias_whole_array => join("\n", q(my @array = (1, 2);),
                                        q(our @ar2 = (1, 2);),
                                        q[\(@array) = \(@ar2);],
                                        q[\(@ar2) = \(@array)]),
        double_diamond => join("\n",    q(while (defined($_ = <<>>)) {),
                                       qq(\tprint()),
                                        q(})),
    );
};

subtest 'perl-5.25.6 split changes' => sub {
    _run_tests(
        excludes_version(v5.25.6),
        split_specials => join("\n",    q(our @s = split('', $a);),
                                        q(my @strings = split(' ', $a))),
    );
};

subtest 'perl-5.28.0' => sub {
    _run_tests(
        requires_version(v5.28.0),
        delete_hash_slice => join("\n", q(my %myhash;),
                                        q(my %a = delete(%myhash{'baz', 'quux'}))),
    );
};

sub requires_version {
    my $ver = shift;
    Devel::Chitin::RequireVersion->new($ver);
}

sub use_feature {
    my $f = shift;
    Devel::Chitin::UseFeature->new($f);
}

sub excludes_version {
    my $ver = shift;
    Devel::Chitin::ExcludeVersion->new($ver);
}

sub excludes_only_version {
    my $ver = shift;
    Devel::Chitin::ExcludeOnlyVersion->new($ver);
}

sub no_warnings {
    my $warn = shift;
    Devel::Chitin::NoWarnings->new($warn);
}

sub _run_tests {
    my @tests = @_;

    my $testwide_preamble = '';
    while (@tests and blessed($tests[0])) {
        my $obj = shift @tests;
        my $directive = $obj->compose();
        if (defined $directive) {
            $testwide_preamble .= $directive;
        } else {
            return ();
        }
    }

    plan tests => _count_tests(@tests);

    while (@tests) {
        my $test_name = shift @tests;

        my $preamble = '';
        while (blessed $tests[0]) {
            $preamble .= shift(@tests)->compose;
        }
        my $code = shift @tests;
        my $eval_string = "${testwide_preamble}${preamble}sub $test_name { $code }";
        my $exception = do {
            local $@;
            eval $eval_string;
            $@;
        };
        if ($exception) {
            die "Couldn't compile code for $test_name: $exception\nCode was:\n$eval_string";
        }
        (my $expected = $code) =~ s/\b(?:my|our)\b\s*//mg;
        my $ops = _get_optree_for_sub_named($test_name);
        my $got = eval { $ops->deparse };
        is($got, $expected, "code for $test_name")
            || do {
                diag("showing whitespace:\n>>".join("<<\n>>", split("\n", $got))."<<");
                diag("\$\@: $@\nTree:\n");
                $ops->print_as_tree
            };
    }
}

sub _count_tests {
    my @tests = @_;
    my $count = 0;
    for (my $i = 0; $i < @tests; $i++) {
        next if ref($tests[$i]);
        $count++;
    }
    return int($count / 2);
}

sub _get_optree_for_sub_named {
    my $subname = shift;
    Devel::Chitin::OpTree->build_from_location(
        Devel::Chitin::Location->new(
            package => 'main',
            subroutine => $subname,
            filename => __FILE__,
            line => 1,
        )
    );
}

package
    Devel::Chitin::TestDirective;
sub new {
    my($class, $code) = @_;
    return bless \$code, $class;
}

package
    Devel::Chitin::RequireVersion;
use base 'Devel::Chitin::TestDirective';
use Test::More;

sub compose {
    my $self = shift;
    my $required_version_string = sprintf('%vd', $$self);
    if ($^V lt $$self) {
        plan skip_all => "needs version $required_version_string";
        return undef;
    }

    my $preamble = "use $required_version_string;";
    if ($^V ge v5.18.0) {
        $preamble .= "\nno warnings 'experimental';";
    }
    return $preamble;
}

package
    Devel::Chitin::ExcludeVersion;
use base 'Devel::Chitin::TestDirective';
use Test::More;

sub compose {
    my $self = shift;
    my $excluded_version_string = sprintf('%vd', $$self);
    if ($^V ge $$self) {
        plan skip_all => "doesn't work starting with version $excluded_version_string";
        return undef;
    }
    return '';
}

package
    Devel::Chitin::ExcludeOnlyVersion;
use base 'Devel::Chitin::TestDirective';
use Test::More;

sub compose {
    my $self = shift;
    my $excluded_version_string = sprintf('%vd', $$self);
    if ($^V eq $$self) {
        plan skip_all => "doesn't work with version $excluded_version_string";
        return undef;
    }
    return '';
}

package
    Devel::Chitin::UseFeature;
use base 'Devel::Chitin::TestDirective';
sub compose {
    my $self = shift;
    sprintf(q(use feature '%s';), $$self);
}

package
    Devel::Chitin::NoWarnings;
use base 'Devel::Chitin::TestDirective';
sub compose {
    my $self = shift;
    $$self ? sprintf(q(no warnings '%s';), $$self) : 'no warnings;';
}
