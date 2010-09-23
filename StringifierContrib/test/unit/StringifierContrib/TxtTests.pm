# Test for Text.pm
package TxtTests;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;

use Foswiki::Contrib::StringifierContrib::Base();
use Foswiki::Contrib::StringifierContrib();

sub set_up {
        my $this = shift;

    $this->SUPER::set_up();

    $this->{attachmentDir} = 'attachement_examples/';
    if (! -e $this->{attachmentDir}) {
        #running from foswiki/test/unit
        $this->{attachmentDir} = 'StringifierContrib/attachement_examples/';
    }
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_stringForFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::StringifierContrib::Plugins::Text->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.txt');
    my $text2 = Foswiki::Contrib::StringifierContrib->stringFor($this->{attachmentDir}.'Simple_example.txt');

    $this->assert(defined($text), "No text returned.");
    
    $this->assert_str_equals($text, $text2, "TXT stringifier not well registered.");

    my $ok = $text =~ /woodstock/;
    $this->assert($ok, "Text woodstock not included")
}

sub test_SpecialCharacters {
    # check that special characters are not destroyed by the stringifier
    
    my $this = shift;
    my $stringifier = Foswiki::Contrib::StringifierContrib::Plugins::Text->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.txt');

    $this->assert_matches('�nderung', $text, "Text �nderung not found.");
}

# test what would happen if someone uploaded a png and called it a .txt
sub test_maliciousFile {
    my $this = shift;
    my $stringifier = Foswiki::Contrib::StringifierContrib::Plugins::Text->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Im_a_png.txt');

    $this->assert_equals('', $text, "Malicious file generated some text?");
}

1;