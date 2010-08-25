# Immediate Notify Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2003 Walter Mundt, emage@spamcop.net
# Copyright (C) 2003 Akkaya Consulting GmbH, jpabel@akkaya.de
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
# =========================
#
# This plugin supports immediate notification of topic saves.
#
# =========================
package Foswiki::Plugins::ImmediateNotifyPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug %methodHandlers
);
use Data::Dumper;

# This should always be $Rev$ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'ImmediateNotifyPlugin';    # Name of this Plugin

sub debug { Foswiki::Func::writeDebug(@_) if $debug; }

sub warning {
    Foswiki::Func::writeWarning(@_);
    debug( "WARNING" . $_[0], @_[ 1 .. $#_ ] );
}

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.011 ) {
        warning("Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    my $prefPrefix = "IMMEDIATENOTIFYPLUGIN_";

    # Get plugin debug flag
    $debug = Foswiki::Func::getPreferencesFlag( $prefPrefix."DEBUG" ) || 0;

    $methods = Foswiki::Func::getPreferencesValue( $prefPrefix . "METHODS" );
    if ( !defined($methods) ) {
        warning("- $pluginName: No METHODS defined in plugin topic, defaulting to SMTP");
        $methods = "SMTP";
        return 0;
    }
    %methodHandlers = ();
    foreach $method ( split ' ', $methods ) {
        debug("- $pluginName: Loading method $method...");
        $modulePresent = eval { require "Foswiki/Plugins/ImmediateNotifyPlugin/$method.pm"; 1 };
        unless ( defined($modulePresent) ) {
            warning("- ${pluginName}::$method failed to load: $@");
            debug("- ${pluginName}::$method failed to load: $@");
            next;
        }

        my $module = "Foswiki::Plugins::ImmediateNotifyPlugin::${method}::";
        if ( eval $module . 'initMethod($topic, $web, $user)' ) {
            $methodHandlers{$method} = eval '\&' . $module . 'handleNotify';
        }
        else {
            debug("- $pluginName: initMethod failed");
        }

        if ( defined( $methodHandlers{$method} ) ) {
            debug("- ImmediateNotifyPlugin::$method OK");
        }
        else {
            warning("- ${pluginName}::$method failed to load");
        }
    }
    unless (%methodHandlers) {
        warning("- $pluginName: No methods available, initialization failed");
        return 0;
    }

    # Plugin correctly initialized
    debug("- Foswiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK");
    return 1;
}

sub processName {
    my ( $name, $users, $groups ) = @_;
    debug("- $pluginName: Processing name $name");
    return if ( length($name) == 0 );
    if ( $name =~ /Group$/go ) {
        return if exists $groups->{$name};    # don't reprocess groups

        $groups->{$name} = undef; # add to hash, leave undef unless GROUP is set
        $groupTopic = Foswiki::Func::readTopicText( $Foswiki::cfg{UsersWebName}, $name );
        unless ( defined($groupTopic) ) {
            warning("- $pluginName: Group topic \"$Foswiki::cfg{UsersWebName}.$name\" not found!");
            return;
        }
        $groupTopic =~ /^\t+\* Set GROUP =(.+)\n[^\t]/sm;
        my @groupMembers = split /[\r\n\s]*[,\s][\r\n\s]*/, $1;
        if (@groupMembers) {
            debug("- $pluginName: Group $name consists of: @groupMembers");
        }
        else {
            debug("- $pluginName: Group $name is undefined or has no members!");
        }
        foreach my $groupMember (@groupMembers) {
            if ( $name =~ /^.*\.(.*)$/ ) {
                processName($2);
            }
            else {
                processName($groupMember);
            }
        }
        $groups->{$name} = [@groupMembers];
    }
    my ($meta, $text) = Foswiki::Func::readTopic( "$Foswiki::cfg{UsersWebName}", "$name" );
    $users->{$name} = $text;
}

sub replaceGroups {
    my ( $name, $method, $methodUsers, $users, $groups ) = @_;
    return unless exists $groups->{$name};

    debug("- $pluginName: Group $name registered for method $method, expanding...");

    delete $methodUsers->{$name};
    foreach $member ( @{ $groups->{$name} } ) {
        if ( exists $groups->{$member} ) {
            replaceGroups( $member, $users, $groups );
        }
        else {
            $methodUsers->{$member} = \$users->{$member};
        }
    }
}

# =========================
sub afterSaveHandler {
    my ( $text, $topic, $web, $error ) = @_;

 # This handler is called by Foswiki::Store::saveTopic just after the save action.

    debug("- ${pluginName}::afterSaveHandler( $_[2].$_[1] )");

    if ($error) {
        debug("- $pluginName: Unsuccessful save, not notifying...");
        return;
    }

    my @names;
    if ( $text =~ /^\t+\* Set IMMEDIATENOTIFY =(.*)\n[^\t]/sm ) {
        @names = split /[\s\r\n]*[,\s][\s\r\n]*/, $1;
    }

    my $notifyTopic = Foswiki::Func::readTopicText( $web, "WebImmediateNotify" );
    $mainWeb = $Foswiki::cfg{UsersWebName};
    while ( $notifyTopic =~ /(\t+|(   )+)\* (?:\%MAINWEB\%|$mainWeb)\.([^\r\n]+)/go )
    {
        push @names, $3 if $3;
        debug("- $pluginName: Adding $3") if ($3);
    }

    unless (@names) {
        debug("- $pluginName: No names registered for notification.");
        return;
    }

    my ( %users, %groups );
    foreach my $name (@names) {
        processName( $name, \%users, \%groups );
    }

    my ( %userTopics, %userMethods );
    foreach my $user ( keys %users ) {
        debug("- $pluginName processing Users: $user"); 
        unless ( defined( $users{$user} ) && length( $users{$user} ) > 0 ) {
            warning("- $pluginName: User topic \"$Foswiki::cfg{UsersWebName}.$user\" not found!");
            next;
        }

        my @methodList = {};
        if ( $users{$user} =~ /(\t+|(   )+)\* Set IMMEDIATENOTIFYMETHOD = ([^\r\n]+)/ )
        {
            @methodList = split / *[, ] */, $3;
        }
        if (@methodList) {
            debug("- $pluginName: User $user: @methodList");
        }
        elsif ( !exists( $group{$member} ) ) {
            debug("- $pluginName: User $user chosen no methods, defaulting to SMTP.");
            @methodList = ("SMTP");
        }
        foreach my $method (@methodList) {
            $userMethods{$user}{$method} = 1;
            debug("- $pluginName: Set method to $method for $user ");
        }
    }

    foreach my $method ( keys %methodHandlers ) {
        debug("- Processing methods $method");
        my %methodUsers =
          map { $userMethods{$_}{$method} ? ( $_, \$users{$_} ) : () }
          keys %users;
        my @userList =
          keys %methodUsers;  # save current key list, so we can modify the hash
        foreach my $user (@userList) {
            debug("replacing groups for $user");
            replaceGroups( $user, $method, \%methodUsers, \%users, \%groups );
        }
        debug( "- $pluginName: $method userlist " . join( " ", keys %methodUsers ) );
        if (%methodUsers) {
            &{ $methodHandlers{$method} }( \%methodUsers );
        }
    }
}

1;
