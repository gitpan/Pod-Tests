package Pod::Tests;

use strict;
use vars qw($VERSION);
$VERSION = '0.07';


=head1 NAME

Pod::Tests - Extracts embedded tests and code examples from POD


=head1 SYNOPSIS

B<LOOK AT Pod::Tests::Tutorial FIRST!>

  use Pod::Tests;
  $p = Pod::Tests->new;

  $p->parse_file($file);
  $p->parse_fh($fh);
  $p->parse(@code);

  my @examples = $p->examples;
  my @tests    = $p->tests;

  foreach my $example (@examples) {
      print "The example:  '$example->{code}' was on line ".
            "$example->{line}\n";
  }

  my @test_code         = $p->build_tests(@tests);
  my @example_test_code = $p->build_examples(@examples);


=head1 DESCRIPTION

B<LOOK AT Pod::Tests::Tutorial FIRST!>

This is a specialized POD viewer to extract embedded tests and code
examples from POD.  It doesn't do much more than that.  pod2test does
the useful work.


=head2 Embedded Tests

Embedding tests allows tests to be placed near the code its testing.
This is a nice supplement to the traditional .t files.

A test is denoted using either "=for testing" or a "=begin/end
testing" block.

   =item B<is_pirate>

        @pirates = is_pirate(@arrrgs);

    Go through @arrrgs and return a list of pirates.

    =begin testing

    my @p = is_pirate('Blargbeard', 'Alfonse', 'Capt. Hampton', 'Wesley');
    ok(@p == 2);

    =end testing

    =cut

    sub is_pirate {
        ....
    }

=head2 Code Examples B<EXPERIMENTAL>

B<BIG FAT WARNING> perldoc and the various pod2* reformatters are
inconsistant in how they deal with =also.  Some warn, some display it,
some choke.  So consider this to be a I<Highly Experimental Feature>.
Also, this interface is B<EXPERIMENTAL AND SUBJECT TO CHANGE>!


Code examples in documentation are rarely tested.  Pod::Tests provides
a way to do some testing of your examples without repeating them.

A code example is denoted using either "=also for example" or an
"=also begin/end example" block.

The C<=also> tag provides that examples will both be extracted B<and>
displayed as documentation.

    =also for example
    print "Here is a fine example of something or other.";

    =also begin example

    use LWP::Simple;
    getprint "http://www.goats.com";

    =also end example

Using a normal C<=for example> or C<=begin/end example> block lets you
add code to your example that won't get displayed.  This is nice when
you only want to show a code fragment, yet still want to ensure things
work.

    =for example
    sub mygrep (&@) { }

    =also for example
    mygrep { $_ eq 'bar' } @stuff

The mygrep() call would be a syntax error were the routine not
declared with the proper prototype.  Pod::Tests will consider both
pieces to the part of the same example for the purposes of testing,
but will only display the C<mygrep {...}> line.  You can also put
C<=for example> blocks afterwards.

You can also put a C<=for example testing> afterwards:

    =also for example
      my $result = 2 + 2;

    =for example_testing
      ok( $result == 4,         'addition works' );

It will work like any other embedded test.  In this case the code will
actually be run.

Finally, since many examples print their output, we trap that into
$_STDOUT_ and $_STDERR_ variables to capture prints and warnings.

    =also for example
      print "Hello, world!\n";
      warn  "Beware the Ides of March!\n";

    =for example_testing
      ok( $_STDOUT_ eq "Hello, world!\n" );
      ok( $_STDERR_ eq "Beware the Ides of March!\n" );

Remember, this is all B<EXPERIMENTAL> and B<SUBJECT TO CHANGE>!


=head2 Formatting

The code examples and embedded tests are B<not> translated from POD,
thus all the CE<lt>E<gt> and BE<lt>E<gt> style escapes are not valid.
Its literal Perl code.


=head2 Parsing

After creating a Pod::Tests object, you parse the POD by calling one
of the available parsing methods documented below.  You can call parse
as many times as you'd like, all examples and tests found will stack
up inside the object.


=head2 Testing

Once extracted, the tests can be built into stand-alone testing code
using the build_tests() and build_examples() methods.  However, it is
recommended that you first look at the pod2test program before
embarking on this.


=head2 Methods

=over 4

=item B<new>

  $parser = Pod::Tests->new;

Returns a new Pod::Tests object which lets you read tests and examples
out of a POD document.

=cut

#'#
sub new {
    my($proto) = shift;
    my($class) = ref $proto || $proto;

    my $self = bless {}, $class;
    $self->_init;
    $self->{example} = [];
    $self->{testing} = [];

    return $self;
}

=pod

=item B<parse>

  $parser->parse(@code);

Finds the examples and tests in a bunch of lines of Perl @code.  Once
run they're available via examples() and testing().

=cut

#'#
sub parse {
    my($self) = shift;

    $self->_init;
    foreach (@_) {
        if( /^=(\w.*)/ and $self->{_sawblank} and !$self->{_inblock}) {
            $self->{_inpod} = 1;

            my($tag, $for, $pod) = split /\s+/, $1, 3;

            if( $tag eq 'also' ) {
                $tag = $for;
                ($for, $pod) = split /\s+/, $pod, 2;
            }

            if( $tag eq 'for' ) {
                $self->_beginfor($for, $pod);
            }
            elsif( $tag eq 'begin' ) {
                $self->_beginblock($for);
            }
            elsif( $tag eq 'cut' ) {
                $self->{_inpod} = 0;
            }

            $self->{_sawblank} = 0;
        }
        elsif( $self->{_inpod} ) {
            if( /^=(?:also )?end (\S+)/ and $self->{_inblock} eq $1 ) {
                $self->_endblock;
                $self->{_sawblank} = 0;
            }
            else {
                if( /^\s*$/ ) {
                    $self->_endfor() if $self->{_infor};
                    $self->{_sawblank} = 1;
                }
                elsif( !$self->{_inblock} and !$self->{_infor} ) {
                    $self->_sawsomethingelse;
                    $self->{_sawblank} = 0;
                }
                $self->{_currpod} .= $_;
            }
        }
        else {
            if( /^\s*$/ ) {
                $self->{_sawblank} = 1;
            }
            else {
                $self->_sawsomethingelse;
            }
        }

        $self->{_linenum}++;
    }

    push @{$self->{example}}, @{$self->{_for}{example}};
    push @{$self->{testing}}, @{$self->{_for}{testing}};
    push @{$self->{example_testing}}, @{$self->{_for}{example_testing}};
}

=begin __private

=item B<_init>

  $parser->_init;

Initializes the state of the parser, but not the rest of the object.
Should be called before each parse of new POD.

=cut

sub _init {
    my($self) = shift;
    $self->{_sawblank}  = 1;
    $self->{_inblock}   = 0;
    $self->{_infor}     = 0;
    $self->{_inpod}     = 0;
    $self->{_linenum}   = 1;
    $self->{_for}       = { example => [],
                            testing => [],
                            example_testing => [],
                          };
}


sub _sawsomethingelse {
    my($self) = shift;
    $self->{_lasttype} = 0;
}


=item B<_beginfor>

  $parser->_beginfor($format, $pod);

Indicates that a =for tag has been seen.  $format (what immediately
follows '=for'), and $pod is the rest of the POD on that line.

=cut

sub _beginfor {
    my($self, $for, $pod) = @_;
    $self->{_infor} = $for;
    $self->{_currpod} = $pod;
    $self->{_forstart} = $self->{_linenum};
}

=item B<_endfor>

  $parser->endfor;

Indicates that the current =for block has ended.

=cut

sub _endfor {
    my($self) = shift;

    my $pod = {
               code => $self->{_currpod},
               line => $self->{_forstart},
              };

    if( $self->{_infor} ) {
        $self->_example_testing($self->{_currpod})
          if $self->{_infor} eq 'example_testing';

        if( $self->{_infor} eq $self->{_lasttype}) {
            ${$self->{_for}{$self->{_infor}}}[-1]{code} .= $self->{_currpod};
        }
        else {
            push @{$self->{_for}{$self->{_infor}}}, $pod;
        }
    }

    $self->{_lasttype} = $self->{_infor};
    $self->{_infor} = 0;
}

=item B<_beginblock>

  $parser->_beginblock($format);

Indicates that the parser saw a =begin tag.  $format is the word
immediately following =begin.

=cut

sub _beginblock {
    my($self, $for) = @_;

    $self->{_inblock} = $for;
    $self->{_currpod} = '';
    $self->{_blockstart} = $self->{_linenum};
}

=item B<_endblock>

  $parser->_endblock

Indicates that the parser saw an =end tag for the current block.

=cut

sub _endblock {
    my($self) = shift;

    my $pod = {
               code => $self->{_currpod},
               line => $self->{_blockstart},
              };

    if( $self->{_inblock} ) {
        $self->_example_testing($self->{_currpod})
          if $self->{_inblock} eq 'example_testing';

        if( $self->{_inblock} eq $self->{_lasttype}) {
            ${$self->{_for}{$self->{_inblock}}}[-1]{code} .= $self->{_currpod};
        }
        else {
            push @{$self->{_for}{$self->{_inblock}}}, $pod;
        }
    }

    $self->{_lasttype} = $self->{_inblock};
    $self->{_inblock} = 0;
}


sub _example_testing {
    my($self, $test) = @_;
    ${$self->{_for}{example}}[-1]{testing} = $test;
}


=end __private

=item B<parse_fh>

=item B<parse_file>

  $parser->parse_file($filename);
  $parser->parse_fh($fh);

Just like parse() except it works on a file or a filehandle, respectively.

=cut

sub parse_file {
    my($self, $file) = @_;

    unless( open(POD, $file) ) {
        warn "Couldn't open POD file $file:  $!\n";
        return;
    }

    return $self->parse_fh(\*POD);
}


sub parse_fh {
    my($self, $fh) = @_;

    # Yeah, this is inefficient.  Sue me.
    return $self->parse(<$fh>);
}

=pod

=item B<examples>

=item B<testing>

  @examples = $parser->examples;
  @testing  = $parser->tests;

Returns the examples and tests found in the parsed POD documents.  Each
element of @examples and @testing is a hash representing an individual
testing block and contains information about that block.

  $test->{code}         actual testing code
  $test->{line}         line from where the test was taken

B<NOTE>  In the future, these will become full-blown objects.

=cut

sub examples {
    my($self) = shift;
    return @{$self->{example}};
}

sub tests {
    my($self) = shift;
    return @{$self->{testing}};
}

=item B<build_tests>

  my @code = $p->build_tests(@tests);

Returns a code fragment based on the given embedded @tests.  This
fragment is expected to print the usual "ok/not ok" (or something
Test::Harness can read) or nothing at all.

Typical usage might be:

    my @code = $p->build_tests($p->tests);

This fragment is suitable for placing into a larger test script.

B<NOTE> Look at pod2test before embarking on your own test building.

=cut

sub build_tests {
    my($self, @tests) = @_;

    my @code = ();

    foreach my $test (@tests) {
        push @code, <<CODE;
# From line $test->{line}
$test->{code}
CODE

    }

    return @code;
}

=item B<build_examples>

  my @code = $p->build_examples(@examples);

Similar to build_tests(), it creates a code fragment which tests the
basic validity of your example code.  Essentially, it just makes sure
it compiles.

If your example has an "example testing" block associated with it it
will run the the example code and the example testing block.

=cut

sub build_examples {
    my($self, @examples) = @_;

    my @code = ();
    foreach my $example (@examples) {
        push @code, <<CODE;
# From line $example->{line}
eval q{
  my \$example = sub {
    no warnings;

$example->{code};

  }
};
is(\$@, '', "example from line $example->{line}");
CODE

        if( $example->{testing} ) {
            $example->{code} .= $example->{testing};
            push @code, $self->build_tests($example);
        }
    }

    return @code;
}

=back

=pod

=head1 EXAMPLES

Here's the simplest example, just finding the tests and examples in a
single module.

  my $p = Pod::Tests->new;
  $p->parse_file("path/to/Some.pm");

And one to find all the tests and examples in a directory of files.  This
illustrates building a set of examples and tests through multiple calls
to parse_file().

  my $p = Pod::Tests->new;
  opendir(PODS, "path/to/some/lib/") || die $!;
  while( my $file = readdir PODS ) {
      $p->parse_file($file);
  }
  printf "Found %d examples and %d tests in path/to/some/lib\n",
         scalar $p->examples, scalar $p->tests;

Finally, an example of parsing your own POD using the DATA filehandle.

  use Fcntl qw(:seek);
  my $p = Pod::Tests->new;

  # Seek to the beginning of the current code.
  seek(DATA, 0, SEEK_SET) || die $!;
  $p->parse_fh(\*DATA);


=head1 AUTHOR

Michael G Schwern <schwern@pobox.com>


=head1 NOTES and CAVEATS

This module is currently EXPERIMENTAL and only for use by pod2test.
If you use it, the interface B<will> change from out from under you.

It currently does B<not> use Pod::Parser.  I couldn't figure out how
to use it.  Instead, I use a simple, home-rolled parser.  This will
eventually be split out as Pod::Parser::Simple.


=head1 SEE ALSO

L<pod2test>, Perl 6 RFC 183  http://dev.perl.org/rfc183.pod

Similar schemes can be found in L<SelfTest> and L<Test::Unit>.

=cut

1;
