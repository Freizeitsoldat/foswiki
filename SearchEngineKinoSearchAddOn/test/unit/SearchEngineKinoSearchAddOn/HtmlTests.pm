# Test for HTML.pm
package HtmlTests;
use base qw( FoswikiFnTestCase );

use strict;

use Foswiki::Func;
use Foswiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase;
use Foswiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier;

sub set_up {
        my $this = shift;
        
    $this->{attachmentDir} = 'attachement_examples/';
    if (! -e $this->{attachmentDir}) {
        #running from foswiki/test/unit
        $this->{attachmentDir} = 'SearchEngineKinoSearchAddOn/attachement_examples/';
    }
    
    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_stringForFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::HTML->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.html');
    my $text2 = Foswiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor($this->{attachmentDir}.'Simple_example.html');

    $this->assert(defined($text), "No text returned.");
    $this->assert_str_equals($text, $text2, "HTML stringifier not well registered.");

    my $ok = $text =~ /Cern/;
    $this->assert($ok, "Text Cern not included");

    $ok = $text =~ /ge�ffnet/;
    $this->assert($ok, "Text ge�ffnet not included");
}

1;
