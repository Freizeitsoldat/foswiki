# Copyright (C) 2011 Foswiki Contributors. All rights reserved.
#
# Tests specific to VC stores, where the history is decoupled from
# the latest rev of the topic. At present that means RCS stores.
# These tests enhance those in StoreTests.pm, but do not replace them.
#
# A VC-controlled file may be in one of four possible states:
#
#    "up to date" means the .txt and .txt,v both exist, and are consistent
#    "inconsistent" means the .txt is newer than the .txt,v
#    "no history" means the .txt exists but there is no .txt,v
#
# Tests for the store in "up to date" state are covered in StoreTests and
# do not need to be repeated here. The tests here are specific to the
# "inconsistent" and "no history" states.

# Coverage:
#  readTopic no history            - verify_NoHistory_getRevisionInfo
#  readTopic inconsistent          - verify_InconsistentTopic_getRevisionInfo
#  getRevisionHistory no history   - verify_NoHistory_getRevisionInfo
#  getRevisionHistory inconsistent - verify_InconsistentTopic_getRevisionInfo
#  getNextRevision no history      - verify_NoHistory_getRevisionInfo
#  getNextRevision inconsistent    - verify_InconsistentTopic_getRevisionInfo
#  saveTopic no history            - verify_NoHistory_implicitSave
#  saveTopic inconsistent          - verify_Inconsistent_implicitSave
#  repRev no history               - verify_NoHistory_repRev
#  repRev inconsistent             - verify_Inconsistent_repRev
#  getVersionInfo no history       - verify_NoHistory_getRevisionInfo
#  getVersionInfo inconsistent     - verify_InconsistentTopic_getRevisionInfo
#  getRevisionAtTime no history    - verify_NoHistory_getRevisionAtTime
#  getRevisionAtTime inconsistent  - verify_Inconsistent_getRevisionAtTime
#  saveAttachment no history 	
#  saveAttachment inconsistent 	
#  getRevisionDiff no history
#  getRevisionDiff inconsistent

package VCStoreTests;

use FoswikiStoreTestCase;
our @ISA = qw( FoswikiStoreTestCase );
use strict;

use Foswiki;
use Foswiki::Meta;

my $TEXT1 = <<'DONE';
He had bought a large map representing the sea,
Without the least vestige of land:
And the crew were much pleased when they found it to be
A map they could all understand. 
DONE

my $TEXT2 = <<DONE;
They sought it with thimbles, they sought it with care;
They pursued it with forks and hope;
They threatened its life with a railway-share;
They charmed it with smiles and soap. 
DONE

my $TEXT3 = <<DONE;
Erect and sublime, for one moment of time.
In the next, that wild figure they saw
(As if stung by a spasm) plunge into a chasm,
While they waited and listened in awe. 
DONE

sub set_up_for_verify {
    my $this = shift;
    $this->{session}->finish();
    $this->{session} = new Foswiki();
}

# private; create a topic with no ,v
sub _createNoHistoryTopic {
    my ($this, $noTOPICINFO) = @_;

    $this->{test_topic} .= "NoHistory";

    open( my $fh, '>', "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt" )
      || die "Unable to open \n $! \n\n ";
    print $fh <<CRUD;
%META:TOPICINFO{author="LewisCarroll" date="9876543210" format="1.1" version="99"}%
$TEXT1
CRUD
    close $fh;

    return 1;
}

# private; create a topic with .txt,v (rev 1, or 99), and a mauled .txt
sub _createInconsistentTopic {
    my ($this, $noTOPICINFO) = @_;

    $this->{test_topic} .= "Inconsistent";

    my $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $meta->text($TEXT1);
    $meta->save(); # we should have a history now, with topic 1 as the latest rev

    # Wait for the clock to tick
    my $x = time;
    while (time == $x) {
	sleep 1;
    }

    # create the mauled content
    open( my $fh, '>', "$Foswiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt" )
      || die "Unable to open \n $! \n\n ";
    print $fh <<CRUD;
%META:TOPICINFO{author="SpongeBobSquarePants" date="1234567890" format="1.1" version="77"}%
$TEXT2
CRUD
    close $fh;

    # The .txt has been mauled, so getLatestRev should return 2

    return 1;
}

# Get revision info where there is no history (,v file)
sub verify_NoHistory_getRevisionInfo {
    my $this = shift;

    $this->_createNoHistoryTopic();

    # A topic without history should be rev 1
    my $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} );
    # 3
    my $it = $this->{session}->{store}->getRevisionHistory($meta);
    $this->assert($it->hasNext());
    $this->assert_num_equals( 1, $it->next() );
    # 1
    $this->assert_matches( qr/^\s*\Q$TEXT1\E\s*$/s, $meta->text() );
#    my $ti = $meta->get('TOPICINFO');
#    $this->assert_num_equals(1, $ti->{version});
#    $this->assert_str_equals($Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID, $ti->{author});

    # 5
    $this->assert_num_equals(2, $this->{session}->{store}->getNextRevision($meta));
    # 17
    my $info = $this->{session}->{store}->getVersionInfo($meta);
    # the TOPICINFO{version} should be ignored if the ,v does not exist, and the rev
    # number reverted to 1
    $this->assert_num_equals(1, $info->{version});
    # the author will be reverted to the unknown user
    $this->assert_str_equals($Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID, $info->{author});
}

sub verify_InconsistentTopic_getRevisionInfo {
    my $this = shift;

    # Inconsistent cache with topicinfo
    $this->_createInconsistentTopic();
    my $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} );
    # 4
    my $it = $this->{session}->{store}->getRevisionHistory($meta);
    $this->assert($it->hasNext());
    $this->assert_num_equals( 2, $it->next() );
    # 6
    $this->assert_num_equals(3, $this->{session}->{store}->getNextRevision($meta));

    # The content should come from the mauled topic
    # 2
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*$/s, $meta->text() );
#    my $ti = $meta->get('TOPICINFO');
#    $this->assert_num_equals(2, $ti->{version});
#    $this->assert_str_equals($Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID, $ti->{author});
    my $info = $this->{session}->{store}->getVersionInfo($meta);
    $this->assert_num_equals(2, $info->{version});
    $this->assert_str_equals($Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID, $info->{author});
}

# A history should be created if none yet exists
sub verify_NoHistory_implicitSave {
    my $this = shift;

    $this->_createNoHistoryTopic();

    # There's no history, but the current .txt is implicit rev 1
    my $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} ); 
    my $it = $this->{session}->{store}->getRevisionHistory($meta);
    $this->assert($it->hasNext());
    $this->assert_num_equals( 1, $it->next() );

    # Save (but *don't* force) a new rev.
    $meta->text( $TEXT2 );
    my $checkSave = $this->{session}->{store}->saveTopic(
	$meta,  $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID, { comment => "unit test" } );

    # Save of a file without an existing history should never modify Rev 1,
    # but should instead create the first revision, so rev 1 represents
    # the original file before history started.

    my $readMeta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $this->assert_equals( 2, $readMeta->getLatestRev() );
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*/s, $readMeta->text() );

    # Check that getRevisionInfo says the right things. The author should be
    # retained, but the date and version number should change
    my $info = $readMeta->getRevisionInfo();
    $this->assert_str_equals( $this->{session}->{user}, $info->{author} );
    $this->assert_num_equals( 2, $info->{version} );

    # Make sure that rev 1 exists and has the original text pre-history.
    $readMeta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic}, 1 );
    $this->assert_matches( qr/^\s*\Q$TEXT1\E\s*$/s, $readMeta->text() );
}

# Save without force revision should create a new rev due to missing history
sub verify_Inconsistent_implicitSave {
    my $this = shift;

    $this->_createInconsistentTopic();

    # Head of "history" will be 2, and should contain $TEXT2
    my $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} ); 

    # Save (but *don't* force) a new rev. Should always create a 3.
    $meta->text( $TEXT3 );
    my $checkSave = $this->{session}->{store}->saveTopic(
	$meta,  $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID, { comment => "unit test" } );

    # Save of a file without an existing history should never modify Rev 1,
    # but should instead create the first revision, so rev 1 represents
    # the original file before history started.

    my $readMeta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $this->assert_equals( 3, $readMeta->getLatestRev() );
    $this->assert_matches( qr/^\s*\Q$TEXT3\E\s*/s, $readMeta->text() );

    # Check that getRevisionInfo says the right things. The author should be
    # retained, but the date and version number should change
    my $info = $readMeta->getRevisionInfo();
    $this->assert_str_equals( $this->{session}->{user}, $info->{author} );
    $this->assert_num_equals( 3, $info->{version} );

    # Make sure that previous revs exist and have the right content
    $readMeta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic}, 1 );
    $this->assert_matches( qr/^\s*\Q$TEXT1\E\s*/s, $readMeta->text() );
    $readMeta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic}, 2 );
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*/s, $readMeta->text() );
    $readMeta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic}, 3 );
    $this->assert_matches( qr/^\s*\Q$TEXT3\E\s*/s, $readMeta->text() );
}

# repRev a topic that has no existing history. The information passed in the repRev call
# will be used to populate the TOPICINFO of the 'new' revision.
sub verify_NoHistory_repRev {
    my $this = shift;

    $this->_createNoHistoryTopic();

    my $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $meta->text($TEXT2);
    # save using a different user (implicit save is done by UNKNOWN user)
    $this->{session}->{store}->repRev( $meta, $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID );
    my $info = $this->{session}->{store}->getVersionInfo($meta);
    $this->assert_num_equals( 1, $info->{version} );
    $this->assert_str_equals( $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID, $info->{author} );
    $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*$/s, $meta->text );
}

sub verify_Inconsistent_repRev {
    my $this = shift;

    $this->_createInconsistentTopic();

    my $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $meta->text($TEXT3);
    # save using a different user (implicit save is done by UNKNOWN user)
    $this->{session}->{store}->repRev( $meta, $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID );
    my $info = $this->{session}->{store}->getVersionInfo($meta);
    $this->assert_num_equals( 2, $info->{version} );
    $this->assert_str_equals( $Foswiki::Users::BaseUserMapping::DEFAULT_USER_CUID, $info->{author} );
    $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $this->assert_matches( qr/^\s*\Q$TEXT3\E\s*$/s, $meta->text );
}

sub verify_NoHistory_getRevisionAtTime {
    my $this = shift;

    my $then = time;
    $this->_createNoHistoryTopic();

    my $meta = Foswiki::Meta->new( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $this->assert_num_equals(1, $this->{session}->{store}->getRevisionAtTime($meta, time));
    $this->assert_null($this->{session}->{store}->getRevisionAtTime($meta, $then-1));
}

# A pending checkin is assumed to have been created at the file modification time of the
# .txt file.
sub verify_Inconsistent_getRevisionAtTime {
    my $this = shift;

    my $then = time;
    $this->_createInconsistentTopic();

    my $meta = Foswiki::Meta->new( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $this->assert_num_equals(2, $this->{session}->{store}->getRevisionAtTime($meta, time));
    $this->assert_num_equals(1, $this->{session}->{store}->getRevisionAtTime($meta, $then));
    $this->assert_null($this->{session}->{store}->getRevisionAtTime($meta, $then-1));
}

# Note this test uses Foswiki::Meta because it is that module that handles the
# decoration of the topic text with meta-data. Less than ideal, but there you go, this
# is really just a sanity check.
sub verify_NoHistory_saveAttachment {
    my $this = shift;

    $this->_createNoHistoryTopic();

    open( FILE, ">", "$Foswiki::cfg{TempfileDir}/testfile.txt" );
    print FILE "one two three";
    close( FILE );

    my $meta = Foswiki::Meta->new( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $meta->attach(name => "testfile.txt",
		  file => "$Foswiki::cfg{TempfileDir}/testfile.txt",
		  comment => "a comment" );

    $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $this->assert_equals( 2, $meta->getLatestRev() );
    $this->assert_matches( qr/^\s*\Q$TEXT1\E\s*/s, $meta->text() );
    $this->assert_not_null($meta->get( 'FILEATTACHMENT', 'testfile.txt' ));

    # Check that the new rev has the attachment meta-data
    my $info = $meta->getRevisionInfo();
    $this->assert_str_equals( $this->{session}->{user}, $info->{author} );
    $this->assert_num_equals( 2, $info->{version} );

    # Make sure that rev 1 exists, has the right text
    $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic}, 1 );
    $this->assert_matches( qr/^\s*\Q$TEXT1\E\s*$/s, $meta->text() );
}

sub verify_Inconsistent_saveAttachment {
    my $this = shift;

    $this->_createInconsistentTopic();

    open( FILE, ">", "$Foswiki::cfg{TempfileDir}/testfile.txt" );
    print FILE "one two three";
    close( FILE );

    my $meta = Foswiki::Meta->new( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $meta->attach(name => "testfile.txt",
		  file => "$Foswiki::cfg{TempfileDir}/testfile.txt",
		  comment => "a comment" );

    $meta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, $this->{test_topic} );
    $this->assert_equals( 3, $meta->getLatestRev() );
    $this->assert_matches( qr/^\s*\Q$TEXT2\E\s*/s, $meta->text() );
    $this->assert_not_null($meta->get( 'FILEATTACHMENT', 'testfile.txt' ));

    # Check that the new rev has the attachment meta-data
    my $info = $meta->getRevisionInfo();
    $this->assert_str_equals( $this->{session}->{user}, $info->{author} );
    $this->assert_num_equals( 3, $info->{version} );
}

1;
