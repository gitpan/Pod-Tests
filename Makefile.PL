# A template for Makefile.PL used by Arena Networks.
# - Set the $PACKAGE variable to the name of your module.
# - Set $LAST_API_CHANGE to reflect the last version you changed the API 
#   of your module.
# - Fill in your dependencies in PREREQ_PM
# Alternatively, you can say the hell with this and use h2xs.

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

$PACKAGE = 'Pod::Tests';
($PACKAGE_FILE = $PACKAGE) =~ s|::|/|g;
$LAST_API_CHANGE = 0;

eval "require $PACKAGE";

unless ($@) { # Make sure we did find the module.
    print <<"CHANGE_WARN" if ${$PACKAGE.'::VERSION'} < $LAST_API_CHANGE;

NOTE: There have been API changes between this version and any older
than version $LAST_API_CHANGE!  Please read the Changes file if you
are upgrading from a version older than $LAST_API_CHANGE.

CHANGE_WARN
}


warn <<API_CHANGE;
*** WARNING *** WARNING *** WARNING *** WARNING *** WARNING *** WARNING ***
         The behavior of Pod::Tests WILL CHANGE NEXT VERSION!!!

Currently, all tests are run in the same lexical scope.  Next version,
each individual testing block will be lexically isolated (ie. have
braces around it).  This means you can't share 'my' variables between
tests, only globals.

Check your tests and modify them now in anticipation.

*** WARNING *** WARNING *** WARNING *** WARNING *** WARNING *** WARNING ***
API_CHANGE

sleep 10;


WriteMakefile(
    NAME            => $PACKAGE,
    VERSION_FROM    => "lib/$PACKAGE_FILE.pm", # finds $VERSION
    PREREQ_PM       => { Test::More     => 0.05,
                         Test::Harness  => 1.22,
                       },
    EXE_FILES       => ['bin/pod2test'],
    'dist'          => { COMPRESS   => 'gzip -9',
                         SUFFIX     => '.gz',
                         DIST_DEFAULT   => 'all tardist',
                       },
);


# Generating pod2test's tests.
print "Running pod2test.\n";
system(qq{$^X -I"lib" bin/pod2test t/Tests.t t/pod2test.t});
