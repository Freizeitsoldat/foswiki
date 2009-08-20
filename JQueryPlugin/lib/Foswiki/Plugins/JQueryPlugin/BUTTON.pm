# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2006-2009 Michael Daum, http://michaeldaumconsulting.com
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. 
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::JQueryPlugin::BUTTON;
use strict;
use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::BUTTON

This is the perl stub for the jquery.button plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless($class->SUPER::new( 
    $session,
    name => 'Button',
    version => '1.1',
    author => 'Michael Daum',
    homepage => 'http://foswiki.org/Extensions/JQueryPlugin',
    tags => 'BUTTON',
    css => ['jquery.button.css'],
    javascript => ['jquery.button.init.js'],
  ), $class);

  $this->{summary} = <<'HERE';
This is a simple way to render nice buttons in Foswiki.
It can be used to replace submit and reset buttons of html forms as well.
Foswiki:Extensions/FamFamFamContrib is recommended to display nice icons
on buttons. Note, that this widget does not participate on the jquery
theme roller. This is independent.
HERE

  return $this;
}

=begin TML

---++ ClassMethod handleBUTTON( $this, $params, $topic, $web ) -> $result

Tag handler for =%<nop>BUTTON%=. 

=cut

sub handleButton {
  my ($this, $params, $theTopic, $theWeb) = @_;

  my $theText = $params->{_DEFAULT} || $params->{value} || $params->{text} || 'Button';
  my $theHref = $params->{href} || '#';
  my $theOnClick = $params->{onclick};
  my $theOnMouseOver = $params->{onmouseover};
  my $theOnMouseOut = $params->{onmouseout};
  my $theTitle = $params->{title};
  my $theIconName = $params->{icon} || '';
  my $theAccessKey = $params->{accesskey};
  my $theId = $params->{id};
  my $theBg = $params->{bg} || '';
  my $theClass = $params->{class} || '';
  my $theStyle = $params->{style} || '';
  my $theTarget = $params->{target};
  my $theType = $params->{type} || 'button';

  $theId = 'jqButton'.Foswiki::Plugins::JQueryPlugin::Plugins::getRandom() unless defined $theId;

  my $theIcon;
  $theIcon = Foswiki::Plugins::JQueryPlugin::Plugins::getIconUrlPath($theIconName) if $theIconName;

  if ($theIcon) {
    $theText = 
      "<span class='jqButtonIcon' style='background-image:url($theIcon)'>$theText</span>";
  }
  $theText = "<span> $theText </span>";

  if ($theTarget) {
    my $url;

    if ($theTarget =~ /^(http|\/).*$/) {
      $url = $theTarget;
    } else {
      my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTarget);
      $url = Foswiki::Func::getViewUrl($web, $topic);
    }
    $theOnClick .= ";window.location.href='$url';";
  }

  if ($theType eq 'submit') {
    $theOnClick .= ";jQuery(this).parents('form:first').submit();";
  }
  if ($theType eq 'save') {
    $theOnClick .= ";var form = jQuery(this).parents('form:first'); if(typeof(foswikiStrikeOne) == 'function') foswikiStrikeOne(form[0]); form.submit();";
  }
  if ($theType eq 'reset') {
    $theOnClick .= ";jQuery(this).parents('form:first').resetForm();";
    Foswiki::Plugins::JQueryPlugin::Plugins::createPlugin('Form');
  }
  if ($theType eq 'clear') {
    $theOnClick .= ";jQuery(this).parents('form:first').clearForm();";
    Foswiki::Plugins::JQueryPlugin::Plugins::createPlugin('Form');
  }
  $theOnClick =~ s/;$//;
  $theOnClick .= ';return false;';

  my $result = "<a id='$theId' class='jqButton $theBg $theClass' href='$theHref'";
  $result .= " accesskey='$theAccessKey' " if $theAccessKey;
  $result .= " title='$theTitle' " if $theTitle;
  $result .= " style='$theStyle' " if $theStyle;

  my @callbacks = ();
  push @callbacks, "onclick:function(){$theOnClick}";
  if ($theOnMouseOver) {
    push @callbacks, "onmouseover:function(){$theOnMouseOver}";
  }
  if ($theOnMouseOut) {
    push @callbacks, "onmouseout:function(){$theOnMouseOut}";
  }
  my $callbacks = join(', ', @callbacks);

  if ($callbacks) {
    Foswiki::Func::addToHEAD("JQUERYPLUGIN::BUTTON::$theId", <<"HERE", 'JQUERYPLUGIN::BUTTON');

<meta name="foswiki.jquery.button.$theId" content="{id:'$theId', $callbacks}" />
HERE
  }

  $result .= ">$theText</a>";
  $result .= "<input type='submit' style='display:none' />" if
    $theType eq 'submit';

  return $result;
}


1;
