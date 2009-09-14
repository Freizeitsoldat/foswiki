# For licensing info read LICENSE file in the Foswiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::PDF;
use base 'Foswiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';

my $pdftotext = $Foswiki::cfg{SearchEngineKinoSearchAddOn}{pdftotextCmd} || 'pdftotext';

# Only if pdftotext exists, I register myself.
if (__PACKAGE__->_programExists($pdftotext)){
    __PACKAGE__->register_handler("application/pdf", ".pdf");}
use File::Temp qw/tmpnam/;

sub stringForFile {
    my ($self, $filename) = @_;
    my $tmp_file = tmpnam();
    my $in;
    my $text;
    
    #unless ((system($pdftotext, $filename, $tmp_file, "-q") == 0) && (-f $tmp_file)) {
    #    return "";
    #}

    
    return '' if (-f $tmp_file);
    
    my $cmd = "$pdftotext $filename $tmp_file -q";
    my ($output, $exit) = Foswiki::Sandbox->sysCommand($cmd);
    
    return '' unless ($exit == 0);
    
    ###########
    # Note: This way, the encoding of the text is reworked in the text stringifier.
    # Note2: May be this is not necessary: My UnitTest says NO...
    $text = Foswiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor($tmp_file);
    
    #open $in, $tmp_file;
    #$text = join(" ", <$in>);
    #close($in);
    ###############

    unlink($tmp_file);

    return $text;
}

1;
