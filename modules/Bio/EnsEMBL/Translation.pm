#
# Ensembl module for Bio::EnsEMBL::Translation
#
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Translation - A class representing the translation of a
transcript

=head1 SYNOPSIS


=head1 DESCRIPTION

A Translation object defines the CDS and UTR regions of a Transcript
through the use of start_Exon/end_Exon, and start/end attributes.

=head1 CONTACT

Post questions to the EnsEMBL Developer list: ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut


package Bio::EnsEMBL::Translation;
use vars qw($AUTOLOAD @ISA);
use strict;

use Bio::EnsEMBL::Utils::Exception qw( deprecate throw warning );
use Bio::EnsEMBL::Utils::Argument qw( rearrange );

use Bio::EnsEMBL::Storable;

@ISA = qw(Bio::EnsEMBL::Storable);



=head2 new

  Arg [-START_EXON] : The Exon object in which the translation (CDS) starts
  Arg [-END_EXON]   : The Exon object in which the translation (CDS) ends
  Arg [-SEQ_START]  : The offset in the start_Exon indicating the start
                      position of the CDS.
  Arg [-SEQ_END]    : The offset in the end_Exon indicating the end
                      position of the CDS.
  Arg [-STABLE_ID]  : The stable identifier for this Translation
  Arg [-VERSION]    : The version of the stable identifier
  Arg [-DBID]       : The internal identifier of this Translation
  Arg [-ADAPTOR]    : The TranslationAdaptor for this Translation
  Arg [-SEQ]        : Manually sets the peptide sequence of this translation.
                      May be useful if this translation is not stored in
                      a database.
  Example    : my $tl = Bio::EnsEMBL::Translation->new
                   (-START_EXON => $ex1,
                    -END_EXON   => $ex2,
                    -SEQ_START  => 98,
                    -SEQ_END    => 39);
  Description: Constructor.  Creates a new Translation object
  Returntype : Bio::EnsEMBL::Translation
  Exceptions : none
  Caller     : general

=cut

sub new {
  my $caller = shift;

  my $class = ref($caller) || $caller;

  my ( $start_exon, $end_exon, $seq_start, $seq_end,
       $stable_id, $version, $dbID, $adaptor, $seq ) = 
    rearrange( [ "START_EXON", "END_EXON", "SEQ_START", "SEQ_END",
                 "STABLE_ID", "VERSION", "DBID", "ADAPTOR",
                 "SEQ" ], @_ );

  my $self = bless {
		    'start_exon' => $start_exon,
		    'end_exon'   => $end_exon,
		    'adaptor'    => $adaptor,
		    'dbID'       => $dbID,
		    'start'      => $seq_start,
		    'end'        => $seq_end,
		    'stable_id'  => $stable_id,
		    'version'    => $version,
        'seq'        => $seq
		   }, $class;

  return $self;
}


=head2 start

 Title   : start
 Usage   : $obj->start($newval)
 Function: return or assign the value of start, which is a position within
           the exon given by start_exon_id.
 Returns : value of start
 Args    : newvalue (optional)


=cut

sub start{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      
      $obj->{'start'} = $value;
    }
    return $obj->{'start'};

}


=head2 end

 Title   : end
 Usage   : $obj->end($newval)
 Function: return or assign the value of end, which is a position within
           the exon given by end_exon.
 Returns : value of end
 Args    : newvalue (optional)


=cut

sub end {
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      
      $self->{'end'} = $value;
    }
    return $self->{'end'};

}


=head2 start_Exon

 Title   : start_exon
 Usage   : $obj->start_Exon($newval)
 Function: return or assign the value of start_exon, which denotes the
           exon at which translation starts (and within this exon, at the
           position indicated by start, see above).
 Returns : value of start_exon (Exon object)
 Args    : newvalue (optional)


=cut

sub start_Exon {
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      if( !ref $value || !$value->isa('Bio::EnsEMBL::Exon') ) {
         throw("Got to have an Exon object, not a $value");
      }
      $self->{'start_exon'} = $value;
    }
   return $self->{'start_exon'};
}




=head2 end_Exon

 Title   : end_exon
 Usage   : $obj->end_Exon($newval)
 Function: return or assign the value of end_exon, which denotes the
           exon at which translation ends (and within this exon, at the
           position indicated by end, see above).
 Returns : value of end_exon (Exon object)
 Args    : newvalue (optional)


=cut

sub end_Exon {
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      if( !ref $value || !$value->isa('Bio::EnsEMBL::Exon') ) {
         throw("Got to have an Exon object, not a $value");
      }
      $self->{'end_exon'} = $value;
    } 

    return $self->{'end_exon'};
}



=head2 version

  Arg [1]    : string $version
  Example    : none
  Description: get/set for attribute version
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub version {
   my $self = shift;
  $self->{'version'} = shift if( @_ );
  return $self->{'version'};
}


=head2 stable_id

  Arg [1]    : string $stable_id
  Example    : none
  Description: get/set for attribute stable_id
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub stable_id {
   my $self = shift;
  $self->{'stable_id'} = shift if( @_ );
  return $self->{'stable_id'};
}



=head2 transform

  Arg  1    : hashref $old_new_exon_map
              a hash that maps old to new exons for a whole gene
  Function  : maps start end end exon according to mapping table
              if an exon is not mapped, just keep the old one
  Returntype: none
  Exceptions: none
  Caller    : Transcript->transform() 

=cut

sub transform {
  my $self = shift;
  my $href_exons = shift;

  my $start_exon = $self->start_Exon();
  my $end_exon = $self->end_Exon();

  if ( exists $href_exons->{$start_exon} ) {
    $self->start_Exon($href_exons->{$start_exon});
  } else {
    # do nothing, the start exon wasnt mapped
  }

  if ( exists $href_exons->{$end_exon} ) {
    $self->end_Exon($href_exons->{$end_exon});
  } else { 
    # do nothing, the end exon wasnt mapped
  }
}


=head2 get_all_DBEntries

  Arg [1]    : none
  Example    : @dbentries = @{$gene->get_all_DBEntries()};
  Description: Retrieves DBEntries (xrefs) for this translation.  

               This method will attempt to lazy-load DBEntries from a
               database if an adaptor is available and no DBEntries are present
               on the translation (i.e. they have not already been added or 
               loaded).
  Returntype : list reference to Bio::EnsEMBL::DBEntry objects
  Exceptions : none
  Caller     : get_all_DBLinks, TranslationAdaptor::store

=cut

sub get_all_DBEntries {
  my $self = shift;

  #if not cached, retrieve all of the xrefs for this gene
  if(!defined $self->{'dbentries'} && $self->adaptor()) {
    $self->{'dbentries'} = 
      $self->adaptor->db->get_DBEntryAdaptor->fetch_all_by_Translation($self);
  }

  $self->{'dbentries'} ||= [];

  return $self->{'dbentries'};
}


=head2 add_DBEntry

  Arg [1]    : Bio::EnsEMBL::DBEntry $dbe
               The dbEntry to be added
  Example    : @dbentries = @{$gene->get_all_DBEntries()};
  Description: Associates a DBEntry with this gene. Note that adding DBEntries
               will prevent future lazy-loading of DBEntries for this gene
               (see get_all_DBEntries).
  Returntype : none
  Exceptions : thrown on incorrect argument type
  Caller     : general

=cut

sub add_DBEntry {
  my $self = shift;
  my $dbe = shift;

  unless($dbe && ref($dbe) && $dbe->isa('Bio::EnsEMBL::DBEntry')) {
    throw('Expected DBEntry argument');
  }

  $self->{'dbentries'} ||= [];
  push @{$self->{'dbentries'}}, $dbe;
}


=head2 get_all_DBLinks

  Arg [1]    : see get_all_DBEntries
  Example    : see get_all_DBEntries
  Description: This is here for consistancy with the Transcript and Gene 
               classes.  It is a synonym for the get_all_DBEntries method.
  Returntype : see get_all_DBEntries
  Exceptions : none
  Caller     : general

=cut

sub get_all_DBLinks {
  my $self = shift;

  return $self->get_all_DBEntries(@_);
}




=head2 get_all_ProteinFeatures

  Arg [1]    : (optional) string $logic_name
               The analysis logic_name of the features to retrieve.  If not
               specified, all features are retrieved instead.
  Example    : $features = $self->get_all_ProteinFeatures('PFam');
  Description: Retrieves all ProteinFeatures associated with this 
               Translation. If a logic_name is specified, only features with 
               that logic_name are returned.  If no logic_name is provided all
               associated protein_features are returned.
  Returntype : Bio::EnsEMBL::ProteinFeature
  Exceptions : none
  Caller     : general

=cut

sub get_all_ProteinFeatures {
  my $self = shift;
  my $logic_name = shift;

  if(!$self->{'protein_features'}) {
    my $adaptor = $self->adaptor();
    my $dbID    = $self->dbID();
    if(!$adaptor || !$dbID) {
      warning("Cannot retrieve ProteinFeatures from translation without " .
              "an attached adaptor and a dbID. Returning empty list.");
      return [];
    }

    my %hash;
    $self->{'protein_features'} = \%hash;

    my $pfa = $adaptor->db()->get_ProteinFeatureAdaptor();
    my $name;
    foreach my $f (@{$pfa->fetch_all_by_translation_id($dbID)}) {
      my $analysis = $f->analysis();
      if($analysis) {
        $name = lc($f->analysis->logic_name());
      } else {
        warning("ProteinFeature has no attached analysis\n");
        $name = '';
      }
      $hash{$name} ||= [];
      push @{$hash{$name}}, $f;
    }
  }

  #a specific type of protein feature was requested
  if(defined($logic_name)) {
    $logic_name = lc($logic_name);
    return $self->{'protein_features'}->{$logic_name} || [];
  }

  my @features;

  #all protein features were requested
  foreach my $type (keys %{$self->{'protein_features'}}) {
    push @features, @{$self->{'protein_features'}->{$type}};
  }

  return \@features;    
}



=head2 get_all_DomainFeatures

  Arg [1]    : none
  Example    : @domain_feats = @{$translation->get_all_DomainFeatures};
  Description: A convenience method which retrieves all protein features
               that are considered to be 'Domain' features.  Features which
               are 'domain' features are those with analysis logic names:
               'pfscan', 'scanprosite', 'superfamily', 'pfam', 'prints'.
  Returntype : listref of Bio::EnsEMBL::ProteinFeatures
  Exceptions : none
  Caller     : webcode (protview)

=cut

sub get_all_DomainFeatures{
 my ($self) = @_;

 my @features;

 my @types = ('pfscan',      #profile (prosite or pfam motifs) 
              'scanprosite', #prosite 
              'superfamily', 
              'pfam',
              'prints');

 foreach my $type (@types) {
   push @features, @{$self->get_all_ProteinFeatures($type)};
 }

 return \@features;
}



=head2 display_id

  Arg [1]    : none
  Example    : print $translation->display_id();
  Description: This method returns a string that is considered to be
               the 'display' identifier.  For translations this is the 
               stable id if it is available otherwise it is an empty string.
  Returntype : string
  Exceptions : none
  Caller     : web drawing code

=cut

sub display_id {
  my $self = shift;
  return $self->{'stable_id'} || '';
}


=head2 length

  Arg [1]    : none
  Example    : print "Peptide length =", $translation->length();
  Description: Retrieves the length of the peptide sequence (i.e. number of
               amino acids) represented by this Translation object.
  Returntype : int
  Exceptions : none
  Caller     : webcode (protview etc.)

=cut

sub length {
  my $self = shift;
  my $seq = $self->seq();

  return ($seq) ? CORE::length($seq) : 0;
}


=head2 seq

  Arg [1]    : none
  Example    : print $translation->seq();
  Description: Retrieves a string representation of the peptide sequence
               of this Translation.  This retrieves the transcript from the
               database and gets its sequence, or retrieves the sequence which
               was set via the constructor.  If no adaptor is attached to this
               translation.
  Returntype : string
  Exceptions : warning if the sequence is not set and cannot be retrieved from
               the database.
  Caller     : webcode (protview etc.)

=cut

sub seq {
  my $self = shift;

  if(@_) {
    $self->{'seq'} = shift;
    return $self->{'seq'};
  }

  return $self->{'seq'} if($self->{'seq'});

  my $adaptor = $self->{'adaptor'};
  if(!$adaptor) {
    warning("Cannot retrieve sequence from Translation - adaptor is not set.");
  }

  my $dbID = $self->{'dbID'};
  if(!$dbID) {
    warning("Cannot retrieve sequence from Translation - dbID is not set.");
  }
  
  my $tr_adaptor = $self->{'adaptor'}->db()->get_TranscriptAdaptor;

  my $seq = $tr_adaptor->fetch_by_translation_id($dbID)->translate();
  $self->{'seq'} = $seq->seq();

  return $self->{'seq'};
}

=head2 get_all_Attributes

  Arg [1]    : optional string $attrib_code
               The code of the attribute type to retrieve values for.
  Example    : ($sc_attr) = @{$tl->get_all_Attributes('_selenocystein')};
               @tl_attributes = @{$translation->get_all_Attributes()};
  Description: Gets a list of Attributes of this translation.
               Optionally just get Attrubutes for given code.
               Recognized attribute "_selenocystein"
  Returntype : listref Bio::EnsEMBL::Attribute
  Exceptions : warning if translation does not have attached adaptor and 
               attempts lazy load.
  Caller     : general, modify_translation

=cut

sub get_all_Attributes {
  my $self = shift;
  my $attrib_code = shift;

  if( ! exists $self->{'attributes' } ) {
    if(!$self->adaptor() ) {
#      warning('Cannot get attributes without an adaptor.');
      return [];
    }

    my $aa = $self->adaptor->db->get_AttributeAdaptor();
    $self->{'attributes'} = $aa->fetch_all_by_Translation( $self );
  }

  if( defined $attrib_code ) {
    my @results = grep { uc($_->code()) eq uc($attrib_code) }
    @{$self->{'attributes'}};
    return \@results;
  } else {
    return $self->{'attributes'};
  }
}


=head2 add_Attributes

  Arg [1...] : Bio::EnsEMBL::Attribute $attribute
               You can have more Attributes as arguments, all will be added.
  Example    : $translation->add_Attributes($selenocystein_attribute);
  Description: Adds an Attribute to the Translation. Usefull to 
               do _selenocystein.
               If you add an attribute before you retrieve any from database, 
               lazy load will be disabled.
  Returntype : none
  Exceptions : throw on incorrect arguments
  Caller     : general

=cut

sub add_Attributes {
  my $self = shift;
  my @attribs = @_;

  if( ! exists $self->{'attributes'} ) {
    $self->{'attributes'} = [];
  }

  for my $attrib ( @attribs ) {
    if( ! $attrib->isa( "Bio::EnsEMBL::Attribute" )) {
      throw( "Argument to add_Attribute must be a Bio::EnsEMBL::Attribute" );
    }
    push( @{$self->{'attributes'}}, $attrib );
  }
}

=head2 get_all_SeqEdits

  Arg [1]    : none
  Example    : my @seqeds = @{$transcript->get_all_SeqEdits()};
  Description: Retrieves all post transcriptional sequence modifications for
               this transcript.
  Returntype : Bio::EnsEMBL::SeqEdit
  Exceptions : none
  Caller     : spliced_seq()

=cut

sub get_all_SeqEdits {
  my $self = shift;

  my @seqeds;

  my $attribs = $self->get_all_Attributes('_selenocystein');

  # convert attributes to SeqEdit objects
  foreach my $a (@$attribs) {
    push @seqeds, Bio::EnsEMBL::SeqEdit->new(-ATTRIB => $a);
  }

  return \@seqeds;
}

=head2 modify_translation

  Arg    1   : Bio::Seq $peptide 
  Example    : my $seq = Bio::Seq->new(-SEQ => $dna)->translate();
               $translation->modify_translation($seq);
  Description: Applies sequence edits such as selenocysteins to the Bio::Seq 
               peptide thats passed in
  Returntype : Bio::Seq
  Exceptions :
  Caller     : Bio::EnsEMBL::Transcript->translate

=cut

sub modify_translation {
  my ($self, $seq) = @_;

  my @seqeds = @{$self->get_all_SeqEdits()};

  # sort in reverse order to avoid complication of adjusting downstream edits
  @seqeds = sort {$b <=> $a} @seqeds;

  # apply all edits
  my $peptide = $seq->seq();
  foreach my $se (@seqeds) {
    $se->apply_edit(\$peptide);
  }
  $seq->seq($peptide);

  return $seq;
}



=head1 DEPRECATED METHODS

=cut


=head2 temporary_id

  Description: DEPRECATED This method should not be needed. Use dbID,
               stable_id or something else.

=cut

sub temporary_id {
   my $self = shift;
   deprecate( "I cant see what a temporary_id is good for, please use " .
               "dbID or stableID or\n try without an id." );
  $self->{'temporary_id'} = shift if( @_ );
  return $self->{'temporary_id'};
}


=head2 get_all_DASFactories

  Arg [1]   : none
  Function  : Retrieves a listref of registered DAS objects
  Returntype: [ DAS_objects ]
  Exceptions:
  Caller    :
  Example   : $dasref = $prot->get_all_DASFactories

=cut

sub get_all_DASFactories {
   my $self = shift;
   return [ $self->adaptor()->db()->_each_DASFeatureFactory ];
}


=head2 get_all_DASFeatures

  Arg [1]    : none
  Example    : $features = $prot->get_all_DASFeatures;
  Description: Retreives a hash reference to a hash of DAS feature
               sets, keyed by the DNS, NOTE the values of this hash
               are an anonymous array containing:
                (1) a pointer to an array of features;
                (2) a pointer to the DAS stylesheet
  Returntype : hashref of Bio::SeqFeatures
  Exceptions : ?
  Caller     : webcode

=cut

sub get_all_DASFeatures{
  my ($self,@args) = @_;
  $self->{_das_features} ||= {}; # Cache
  my %das_features;
  foreach my $dasfact( @{$self->get_all_DASFactories} ){
    my $dsn  = $dasfact->adaptor->dsn;
    my $name = $dasfact->adaptor->name;
    $name ||= $dasfact->adaptor->url .'/'. $dsn;
    if( $self->{_das_features}->{$name} ){ # Use cached
      $das_features{$name} = $self->{_das_features}->{$name};
      next;
    }
    else{ # Get fresh data
      my @featref = $dasfact->fetch_all_by_DBLink_Container( $self );
      $self->{_das_features}->{$name} = [@featref];
      $das_features{$name} = [@featref];
    }
  }
  return \%das_features;
}

1;
