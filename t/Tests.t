# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use Test::More no_plan;

BEGIN { use_ok 'Pod::Tests'; }


my $p = Pod::Tests->new;
$p->parse_fh(*DATA);

my @tests       = $p->tests;
my @examples    = $p->examples;

is( @tests,     2,                      'saw tests' );
is( @examples,  4,                      'saw examples' );

is( $tests[0]{line},    10 );
is( $tests[0]{code},    <<'POD',        'saw =for testing' );
ok(2+2 == 4);
POD

is( $tests[1]{line},     21 );
is( $tests[1]{code},    <<'POD',        'saw testing block' );

my $foo = 0;
ok( !$foo,      'foo is false' );
ok( $foo == 0,  'foo is zero'  );

POD

is( $examples[0]{line},  31 );
is( $examples[0]{code}, <<'POD',        'saw example block' );

  # This is an example.
  2+2 == 4;
  5+5 == 10;

POD

is( $examples[1]{line}, 41 );
is( $examples[1]{code}, <<'POD',       'multi-part example glued together' );
  sub mygrep (&@) { }
  mygrep { $_ eq 'bar' } @stuff
POD

is( $examples[2]{line}, 49 );
is( $examples[2]{code}, <<'POD',        'example with tests' );
  my $result = 2 + 2;
POD
is( $examples[2]{testing}, <<'POD',     q{  and there's the tests});
  ok( $result == 4,         'addition works' );
POD


# Test that double parsing works.

# Seek back to __END__.
use POSIX qw( :fcntl_h );
seek(DATA, 0, SEEK_SET) || die $!;
do { $_ = <DATA> } until /^__END__$/;

$p->parse_fh(*DATA);

is( $p->tests,       4,                      'double parse tests' );
is( $p->examples,    8,                      'double parse examples' );



__END__
code and things

=for something_else
  Make sure Pod::Tests ignores other =for tags.

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
ok( !$foo,      'foo is false' );
ok( $foo == 0,  'foo is zero'  );

=end testing

Neither is this.

=also begin example

  # This is an example.
  2+2 == 4;
  5+5 == 10;

=also end example

Let's try an example with helper code.

=for example
  sub mygrep (&@) { }

=also for example
  mygrep { $_ eq 'bar' } @stuff

And an example_testing block

=also for example
  my $result = 2 + 2;

=for example_testing
  ok( $result == 4,         'addition works' );

And the special $_STDOUT_ and $_STDERR_ variables..

=also for example
  print "Hello, world!\n";
  warn  "Beware the Ides of March!\n";

=for example_testing
  ok( $_STDOUT_ eq "Hello, world!\n",                   '$_STDOUT_' );
  ok( $_STDERR_ eq "Beware the Ides of March!\n",       '$_STDERR_' );


=cut

1;
