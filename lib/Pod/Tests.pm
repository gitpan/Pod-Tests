package Pod::Tests;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';


=pod

=head1 NAME

Pod::Tests - Extracts embedded tests and code examples from POD


=head1 SYNOPSIS

B<LOOK AT pod2test FIRST!>

  use Pod::Tests;
  $p->new;

  $p->parse_file($file);
  $p->parse_fh($fh);
  $p->parse(@code);

  my @examples = $p->examples;
  my @tests    = $p->tests;

  foreach my $example (@examples) {
      print "The example:  '$example->{code}' was on line ".
            "$example->{line}\n";
  }


=head1 DESCRIPTION

B<LOOK AT pod2test FIRST!  THIS IS ALPHA CODE!>

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


Code examples in documentation are rarely tested.  Pod::Tests provides
a way to do some minimalist testing of your examples.

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


=head2 Formatting

The code examples and embedded tests are B<not> translated from POD,
thus all the CE<lt>E<gt> and BE<lt>E<gt> style escapes are not valid.
Its literal Perl code.


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
    return $self;
}

=pod

=item B<parse>

  $parser->parse(@code);

Finds the examples and tests in a bunch of lines of Perl @code.  Once
run they're available via examples() and testing().

=cut

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
                else {
                    $self->{_sawblank} = 0;
                }
                $self->{_currpod} .= $_;
            }
1        }
        else {
            if( /^\s*$/ ) {
                $self->{_sawblank} = 1;
            }
        }

        $self->{_linenum}++;
    }

    $self->{example} = $self->{_for}{example};
    $self->{testing} = $self->{_for}{testing};
}


sub _init {
    my($self) = shift;
    $self->{_sawblank}  = 1;
    $self->{_inblock}   = 0;
    $self->{_infor}     = 0;
    $self->{_inpod}     = 0;
    $self->{_linenum}   = 1;
}


sub _beginfor {
    my($self, $for, $pod) = @_;
    $self->{_infor} = $for;
    $self->{_currpod} = $pod;
    $self->{_forstart} = $self->{_linenum};
}


sub _endfor {
    my($self) = shift;

    my $pod = {
               code => $self->{_currpod},
               line => $self->{_forstart},
              };

    push @{$self->{_for}{$self->{_infor}}}, $pod if
      $self->{_infor};

    $self->{_infor} = 0;
}


sub _beginblock {
    my($self, $for) = @_;

    $self->{_inblock} = $for;
    $self->{_currpod} = '';
    $self->{_blockstart} = $self->{_linenum};
}


sub _endblock {
    my($self) = shift;

    my $pod = {
               code => $self->{_currpod},
               line => $self->{_blockstart},
              };

    push @{$self->{_for}{$self->{_inblock}}}, $pod if
      $self->{_inblock};

    $self->{_inblock} = 0;
}


=pod

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

=pod

=head1 AUTHOR

Michael G Schwern <schwern@pobox.com>


=head1 NOTES and CAVEATS

This module is currently EXPERIMENTAL and only for use by pod2test.
If you use it, the interface B<will> change from out from under you.

It currently does B<not> use Pod::Parser.  The thing is too
complicated, I couldn't figure out how to use it.  Instead, I use a
simple, home-rolled parser.  This will eventually be split out as
Pod::Parser::Simple.


=head1 SEE ALSO

L<pod2test>, 
Perl 6 RFC 183  http://dev.perl.org/rfc183.pod

=cut

1;
