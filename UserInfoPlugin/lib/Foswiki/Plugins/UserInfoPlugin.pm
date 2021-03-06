# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
#
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
#

package Foswiki::Plugins::UserInfoPlugin;

use strict;
use vars qw( $VERSION $RELEASE $uipCore );

$VERSION = '$Rev$';
$RELEASE = '1.55';

###############################################################################
sub initPlugin {
  #($topic, $web, $user, $installWeb) = @_;

  $uipCore = undef;
  return 1;
}

###############################################################################
sub commonTagsHandler {
  $_[0] =~ s/%NR(VISITORS|USERS|GUESTS)%/&handleSimpleTags($1)/ge;
  $_[0] =~ s/%(VISITORS|LASTVISITORS|NRLASTVISITORS|NEWUSERS)(?:{(.*?)})?%/&handleTags($1, $2)/ge;
}

###############################################################################
sub getCore {
  return $uipCore if $uipCore;

  eval 'use Foswiki::Plugins::UserInfoPlugin::Core;';
  die $@ if $@;

  $uipCore = new Foswiki::Plugins::UserInfoPlugin::Core;

  return $uipCore;
}

###############################################################################
sub handleSimpleTags {
  my $mode = shift;

  my $core = getCore();

  return $core->handleNrVisitors() if $mode eq 'VISITORS';
  return $core->handleNrUsers() if $mode eq 'USERS';
  return $core->handleNrGuests()#; if $mode eq 'GUESTS';
}

###############################################################################
sub handleTags {
  my $mode = shift;

  my $core = getCore();

  return $core->handleNrLastVisitors(@_) if $mode eq 'NRLASTVISITORS';
  return $core->handleCurrentVisitors(@_) if $mode eq 'VISITORS';
  return $core->handleLastVisitors(@_) if $mode eq 'LASTVISITORS';
  return $core->handleNewUsers(@_);# if $mode eq 'NEWUSERS';
}

###############################################################################

1;

