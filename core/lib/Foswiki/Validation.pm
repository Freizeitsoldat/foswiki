# See bottom of file for license and copyright information
package Foswiki::Validation;

use strict;
use warnings;

use Assert;

use Digest::MD5 ();
use Foswiki     ();

=begin TML

---+ package Foswiki::Validation

"Validation" is the process of ensuring that an incoming request came from
a page we generated. Validation keys are injected into all HTML pages
generated by Foswiki, in Foswiki::writeCompletePage. When a request is
received from the browser that requires validation, that request must
be accompanied by the validation key. The functions in this package
support the generation and checking of these validation keys.

Two key validation methods are supported by this module; simple token
validation, and double-submission validation. Simple token validation
stores a magic number in the session, and then adds that magic number to
all forms in the output HTML. When a form is submitted, the magic number
submitted with the form must match the number stored in the session. This is
a relatively weak protection method, but requires some coding around so may
discourage many hackers.

The second method supported is properly called double cookie submission,
but referred to as "strikeone" in Foswiki. This again uses a token added
to output forms, but this time it uses Javascript to combine that token
with a secret stored in a cookie, to create a new token. This is more secure
because the cookie containing the secret cannot be read outside the domain
of the server, making it much harder for a page hosted on an evil site to
forge a valid transaction.

When a request requiring validation comes in, Foswiki::UI::checkValidationKey
is called. This compares the key in the request with the set of valid keys
stored in the session. If the comparison fails, the browser is redirected
to the =login= script (even if the user is currently logged in) with the
=action= parameter set to =validate=. This generates a confirmation screen
that the user must accept before the transaction can proceed. When the screen
is confirmed, =login= is invoked again and the original transaction restored
from passthrough.

In the function descriptions below, $cgis is a reference to a CGI::Session
object.

=cut

# Set to 1 to trace validation steps in STDERR
use constant TRACE => 0;

# Define cookie name only once
# WARNING: If you change this, be sure to also change the javascript
sub _getSecretCookieName { 'FOSWIKISTRIKEONE' }

=begin TML

---++ StaticMethod addValidationKey( $cgis, $context, $strikeone ) -> $form

Add a new validation key to a form. The key will time out after
{Validation}{ValidForTime}.
   * =$cgis= - a CGI::Session
   * =$context= - the context for the key, usually the URL of the target
     page plus the time. This should be unique for each rendered page.
   * =$strikeone= - if set, expect the nonce to be combined with the
     session secret before it is posted back.
The validation key will be added as a hidden parameter at the end of
the form tag.

=cut

sub addValidationKey {
    my ( $cgis, $context, $strikeone ) = @_;

    my $nonce = generateValidationKey($cgis, $context, $strikeone);

    # Don't use CGI::hidden; it will inherit the URL param value of
    # validation key and override our value :-(
    return "<input type='hidden' name='validation_key' value='?$nonce' />";
}

=begin TML

---++ StaticMethod generateValidationKey( $cgis, $context, $strikeone ) -> $nonce

Generate a new validation key. The key will time out after
{Validation}{ValidForTime}.
   * =$cgis= - a CGI::Session
   * =$context= - the context for the key, usually the URL of the target
     page plus the time. This should be unique for each rendered page.
   * =$strikeone= - if set, expect the nonce to be combined with the
     session secret before it is posted back.
The validation key wcan then be used in a HTML form, or headers for RestPlugin API etc.
TODO: should this be assable from Foswiki::Func so that RestHandlers can use it too?

=cut

sub generateValidationKey {
    my ( $cgis, $context, $strikeone ) = @_;
    my $actions = $cgis->param('VALID_ACTIONS') || {};
    my $nonce = Digest::MD5::md5_hex( $context, $cgis->id() );
    my $action = $nonce;
    if ($strikeone) {

        # When using strikeone, the validation key pushed into the form will
        # be combined with the secret in the cookie, and the combination
        # will be md5 encoded before sending back. Since we know the secret
        # and the validation key, then might as well save the hashed version.
        # This has to be consistent with the algorithm in strikeone.js
        my $secret = _getSecret($cgis);
        $action = Digest::MD5::md5_hex( $nonce, $secret );

        #print STDERR "V: STRIKEONE $nonce + $secret = $action\n" if TRACE;
    }
    my $timeout = time() + $Foswiki::cfg{Validation}{ValidForTime};
    print STDERR "V: ADD KEY $action"
      . ( $nonce ne $action ? "($nonce)" : '' ) . ' = '
      . $timeout . "\n"
      if TRACE && !defined $actions->{$action};
    $actions->{$action} = $timeout;
    
    #used to store the actions in case there are more than one form..
    $cgis->param( 'VALID_ACTIONS', $actions );


    return $nonce;
}

=begin TML

---++ StaticMethod addOnSubmit( $form ) -> $form

Add a double submission onsubmit handler to a form.
   * =$form= - the opening tag of a form, ie. &lt;form ...&gt;=
The handler will be added to an existing on submit, or by adding a new
onsubmit in the form tag.

=cut

sub addOnSubmit {
    my ($form) = @_;
    unless ( $form =~
s/\bonsubmit=(["'])((?:\s*javascript:)?)(.*)\1/onsubmit=${1}${2}StrikeOne.submit(this);$3$1/i
      )
    {
        $form =~ s/>$/ onsubmit="StrikeOne.submit(this)">/;
    }
    return $form;
}

=begin TML

---++ StaticMethod getCookie( $cgis ) -> $cookie

Get a double submission cookie
   * =$cgis= - a CGI::Session

The cookie is a non-HttpOnly cookie that contains the current session ID
and a secret. The secret is constant for a given session.

=cut

sub getCookie {
    my ($cgis) = @_;

    my $secret = _getSecret($cgis);

    # Add the cookie to the response
    require CGI::Cookie;
    my $cookie = CGI::Cookie->new(
        -name  => _getSecretCookieName(),
        -value => $secret,
        -path  => '/',
        -httponly => 0,    # we *want* JS to be able to read it!
    );

    return $cookie;
}

=begin TML

---++ StaticMethod isValidNonce( $cgis, $key ) -> $boolean

Check that the given validation key is valid for the session.
Return false if not.

=cut

sub isValidNonce {
    my ( $cgis, $nonce ) = @_;
    my $actions = $cgis->param('VALID_ACTIONS');
    return isValidNonceHash($actions, $nonce)
}


=begin TML

---++ StaticMethod isValidNonceHash( $actions, $key ) -> $boolean

Check that the given validation key is valid for the session.
Return false if not.

=cut

sub isValidNonceHash {
    my ( $actions, $nonce ) = @_;
    return 1 if ( $Foswiki::cfg{Validation}{Method} eq 'none' );
    return 0 unless defined $nonce;
    $nonce =~ s/^\?// if ( $Foswiki::cfg{Validation}{Method} ne 'strikeone' );
    return 0 unless ref($actions) eq 'HASH';
    print STDERR "V: CHECK $nonce -> " . ( $actions->{$nonce} ? 1 : 0 ) . "\n"
      if TRACE;
    return $actions->{$nonce};
}

=begin TML

---++ StaticMethod expireValidationKeys($cgis[, $key])

Expire any timed-out validation keys for this session, and (optionally)
force expiry of a specific key, even if it hasn't timed out.

=cut

sub expireValidationKeys {
    my ( $cgis, $key ) = @_;
    my $actions = $cgis->param('VALID_ACTIONS');
    if ($actions) {
        if ( defined $key && exists $actions->{$key} ) {
            $actions->{$key} = 0;    # force-expire this key
        }
        my $deaths = 0;
        my $now    = time();
        while ( my ( $nonce, $time ) = each %$actions ) {
            if ( $time < $now ) {

                print STDERR "V: EXPIRE $nonce $time\n" if TRACE;
                delete $actions->{$nonce};
                $deaths++;
            }
        }

        # If we have more than the permitted number of keys, expire
        # the oldest ones.
        my $excess =
          scalar( keys %$actions ) -
          $Foswiki::cfg{Validation}{MaxKeysPerSession};
        if ( $excess > 0 ) {
            print STDERR "V: $excess TOO MANY KEYS\n" if TRACE;
            my @keys = sort { $actions->{$a} <=> $actions->{$b} }
              keys %$actions;
            while ( $excess-- > 0 ) {
                my $key = shift(@keys);
                print STDERR "V: EXPIRE $key $actions->{$key}\n" if TRACE;
                delete $actions->{$key};
                $deaths++;
            }
        }
        if ($deaths) {
            $cgis->param( 'VALID_ACTIONS', $actions );
        }
    }
}

=begin TML

---++ StaticMethod validate($session)

Generate (or check) the "Suspicious request" verification screen for the
given session. This screen is generated when a validation fails, as a
response to a ValidationException.

=cut

sub validate {
    my ($session) = @_;
    my $query     = $session->{request};
    my $web       = $session->{webName};
    my $topic     = $session->{topicName};
    my $cgis      = $session->getCGISession();

    my $tmpl = $session->templates->readTemplate( 'validate' );

    if ( $query->param('response') ) {
        my $cacheUID = $query->param('foswikioriginalquery');
        $query->delete('foswikioriginalquery');
        my $url;
        if ( $query->param('response') eq 'OK'
            && isValidNonce( $cgis, $query->param('validation_key') ) )
        {
            if ( !$cacheUID ) {
                $url = $session->getScriptUrl( 0, 'view', $web, $topic );
            }
            else {

                # Reload the cached original query over the current query.
                # When the redirect is validated it should pass, because
                # it will now be using the validation code from the
                # confirmation screen that brought us here.
                require Foswiki::Request::Cache;
                Foswiki::Request::Cache->new()->load( $cacheUID, $query );
                $url = $query->url();
            }

            # Complete the query by passing the query on
            # with passthrough
            print STDERR "WV: CONFIRMED; POST to $url\n" if TRACE;
            $session->redirect( $url, 1 );
        }
        else {
            print STDERR "V: CONFIRMATION REJECTED\n" if TRACE;

            # Validation failed; redirect to view (302)
            $url = $session->getScriptUrl( 0, 'view', $web, $topic );
            $session->redirect( $url, 0 );    # no passthrough
        }
    }
    else {

        print STDERR "V: PROMPTING FOR CONFIRMATION " . $query->uri() . "\n"
          if TRACE;

        # Prompt for user verification - code 419 chosen by foswiki devs.
        # None of the defined HTTP codes describe what is really happening,
        # which is why we chose a "new" code. The confirmation page
        # isn't a conflict, not a security issue, and we cannot use 403
        # because there is a high probability this would get caught by
        # Apache to send back the Registation page. We didn't want any
        # installation to catch the HTTP return code we were sending back,
        # as we need this page to arrive intact to the user, otherwise
        # they won't be able to do anything. 419 is a placebo, and if it
        # is ever defined can be replaced by any other undefined 4xx code.
        $session->{response}->status(419);

        my $topicObject = Foswiki::Meta->new( $session, $web, $topic );
        $tmpl = $topicObject->expandMacros($tmpl);
        $tmpl = $topicObject->renderTML($tmpl);
        $tmpl =~ s/<nop>//g;

        $session->writeCompletePage($tmpl);
    }
}

# Get/set the one-strike secret in the CGI::Session
sub _getSecret {
    my $cgis   = shift;
    my $secret = $cgis->param( _getSecretCookieName() );
    unless ($secret) {

        # Use hex encoding to make it cookie-friendly
        $secret = Digest::MD5::md5_hex( $cgis->id(), rand(time) );
        $cgis->param( _getSecretCookieName(), $secret );
    }
    return $secret;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
