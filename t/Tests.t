# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)
use strict;

use vars qw($Total_tests);

my $loaded;
my $test_num = 1;
BEGIN { $| = 1; $^W = 1; }
END {print "not ok $test_num\n" unless $loaded;}
print "1..$Total_tests\n";
use Pod::Tests;
$loaded = 1;
ok(1, 'compile');
######################### End of black magic.

# Utility testing functions.
sub ok {
    my($test, $name) = @_;
    print "not " unless $test;
    print "ok $test_num";
    print " - $name" if defined $name;
    print "\n";
    $test_num++;
}

sub eqarray  {
    my($a1, $a2) = @_;
    return 0 unless @$a1 == @$a2;
    my $ok = 1;
    for (0..$#{$a1}) { 
        unless($a1->[$_] eq $a2->[$_]) {
        $ok = 0;
        last;
        }
    }
    return $ok;
}

# Change this to your # of ok() calls + 1
BEGIN { $Total_tests = 11 }

my $p = Pod::Tests->new;
$p->parse_fh(*DATA);

my @tests       = $p->tests;
my @examples    = $p->examples;

ok( @tests      == 2,                      'saw tests' );
ok( @examples   == 1,                      'saw examples' );

ok( $tests[0]{line} == 7 );
ok( $tests[0]{code} eq <<'POD',        'saw =for testing' );
ok(2+2 == 4);
POD

ok( $tests[1]{line} == 18 );
ok( $tests[1]{code} eq <<'POD',        'saw testing block' );

my $foo = 0;
ok( !$foo );

POD

ok( $examples[0]{line} == 27 );
ok( $examples[0]{code} eq <<'POD',        'saw example block' );

2+2 == 4;
5+5 == 10;

POD


# Test that double parsing works.

# Seek back to __END__.
use Fcntl qw(:seek);
seek(DATA, 0, SEEK_SET) || die $!;
do { $_ = <DATA> } until /^__END__$/;

$p->parse_fh(*DATA);

ok( $p->tests      == 4,                      'double parse tests' );
ok( $p->examples   == 2,                      'double parse examples' );



__END__
code and things

=head1 NAME

Dummy testing file for Pod::Tests

=for testing
ok(2+2 == 4);

This is not a test

=cut

code and stuff

=pod

=begin testing

my $foo = 0;
ok( !$foo );

=end testing

Neither is this.

=also begin example

2+2 == 4;
5+5 == 10;

=also end example

=cut

1;
