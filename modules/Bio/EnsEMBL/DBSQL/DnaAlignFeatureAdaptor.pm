#
# EnsEMBL module for Bio::EnsEMBL::DnaAlignFeatureAdaptor
#
# Copyright (c) 2003 EnsEMBL
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

Bio::EnsEMBL::DBSQL::DnaAlignFeatureAdaptor - Adaptor for DnaAlignFeatures

=head1 SYNOPSIS

    $dafa = $dbadaptor->get_DnaAlignFeatureAdaptor();

    @features = @{$dafa->fetch_by_Slice($slice)};

    $dafa->store(@features);

=head1 DESCRIPTION

This is an adaptor for DNA features on DNA sequence. Like other
feature getting adaptors it has a number of fetch_ functions and a
store function. This adaptor inherits most of its functionality from
its BaseAlignFeatureAdaptor superclass.

=head1 CONTACT

Post questions to the EnsEMBL development list <ensembl-dev@ebi.ac.uk>

=cut


package Bio::EnsEMBL::DBSQL::DnaAlignFeatureAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::DBSQL::BaseAlignFeatureAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAlignFeatureAdaptor);


=head2 _tables

  Args       : none
  Example    : @tabs = $self->_tables
  Description: PROTECTED implementation of the abstract method inherited from
               BaseFeatureAdaptor.  Returns list of [tablename, alias] pairs
  Returntype : list of listrefs of strings
  Exceptions : none
  Caller     : Bio::EnsEMBL::DBSQL::BaseFeatureAdaptor::generic_fetch

=cut

sub _tables {
  my $self = shift;

  return ['dna_align_feature', 'daf'];
}


=head2 _columns

  Args       : none
  Example    : @columns = $self->_columns
  Description: PROTECTED implementation of abstract superclass method.  
               Returns a list of columns that are needed for object creation.
  Returntype : list of strings
  Exceptions : none
  Caller     : Bio::EnsEMBL::DBSQL::BaseFeatureAdaptor::generic_fetch

=cut

sub _columns {
  my $self = shift;

  #warning, implementation of _objs_from_sth method depends on order of list
  return qw(daf.dna_align_feature_id
            daf.seq_region_id
            daf.analysis_id
            daf.seq_region_start
            daf.seq_region_end
            daf.seq_region_strand
            daf.hit_start
            daf.hit_end
            daf.hit_name
            daf.hit_strand
            daf.cigar_line
            daf.evalue
            daf.perc_ident
            daf.score);
}


=head2 store

  Arg [1]    : list of Bio::EnsEMBL::DnaAlignFeatures @feats
               the features to store in the database
  Example    : $dna_align_feature_adaptor->store(@features);
  Description: Stores a list of DnaAlignFeatures in the database
  Returntype : none
  Exceptions : throw if any of the provided features cannot be stored
               which may occur if:
               * The feature does not have an associate Slice
               * The feature has already been stored in this db
               * The feature does not have an associated analysis
               * The Slice the feature is associated with is on a seq_region
                 unknown to this database
  Caller     : Pipeline

=cut

sub store {
  my ($self, @feats) = @_;

  throw("Must call store with features") if( scalar(@feats) == 0 );

  my @tabs = $self->_tables;
  my ($tablename) = @{$tabs[0]};

  my $db = $self->db();
  my $slice_adaptor = $db->get_SliceAdaptor();
  my $analysis_adaptor = $db->get_AnalysisAdaptor();

  my $sth = $self->prepare(
     "INSERT INTO $tablename (seq_region_id, seq_region_start, seq_region_end,
                             seq_region_strand, hit_start, hit_end,
                             hit_strand, hit_name, cigar_line,
                             analysis_id, score, evalue, perc_ident)
     VALUES (?,?,?,?,?,?,?,?,?,?,?, ?, ?)");

  foreach my $feat ( @feats ) {
    if( !ref $feat || !$feat->isa("Bio::EnsEMBL::DnaDnaAlignFeature") ) {
      throw("feature must be a Bio::EnsEMBL::DnaDnaAlignFeature,"
            . " not a [".ref($feat)."].");
    }

    if($feat->is_stored($db)) {
      throw('Feature is already stored in this database.');
    }

    my $slice = $feat->slice();
    if(!defined($slice) || !$slice->isa("Bio::EnsEMBL::Slice")) {
      throw("A slice must be attached to the features to be stored.");
    }

    if(!defined($feat->analysis)) {
      throw("An analysis must be attached to the features to be stored.");
    }

    #store the analysis if it has not been stored yet
    if(!$feat->analysis->is_stored($db)) {
      $analysis_adaptor->store($feat->analysis());
    }

    my $seq_region_id = $slice_adaptor->get_seq_region_id($slice);

    if(!$seq_region_id) {
      throw('Feature is on seq_region which is not in this database: ' .
            $slice->name() . " and may not be stored.");
    }

    $sth->execute( $seq_region_id, $feat->start, $feat->end, $feat->strand,
		   $feat->hstart, $feat->hend, $feat->hstrand, $feat->hseqname,
		   $feat->cigar_string, $feat->analysis->dbID, $feat->score,
		   $feat->p_value, $feat->percent_id);
    $feat->dbID($sth->{'mysql_insertid'});
    $feat->adaptor($self);
  }

  $sth->finish();
}


=head2 _objs_from_sth

  Arg [1]    : DBI statement handle $sth
               an exectuted DBI statement handle generated by selecting 
               the columns specified by _columns() from the table specified 
               by _table()
  Example    : @dna_dna_align_feats = $self->_obj_from_hashref
  Description: PROTECTED implementation of superclass abstract method. 
               Creates DnaDnaAlignFeature objects from a DBI hashref
  Returntype : listref of Bio::EnsEMBL::DnaDnaAlignFeatures
  Exceptions : none
  Caller     : Bio::EnsEMBL::BaseFeatureAdaptor::generic_fetch

=cut

sub _objs_from_sth {
  my ($self, $sth, $mapper, $dest_slice) = @_;

  #
  # This code is ugly because an attempt has been made to remove as many
  # function calls as possible for speed purposes.  Thus many caches and
  # a fair bit of gymnastics is used.
  #

  my $sa = $self->db()->get_SliceAdaptor();
  my $aa = $self->db->get_AnalysisAdaptor();

  my @features;
  my %analysis_hash;
  my %slice_hash;
  my %sr_name_hash;
  my %sr_cs_hash;

  my($dna_align_feature_id, $seq_region_id, $analysis_id, $seq_region_start,
     $seq_region_end, $seq_region_strand, $hit_start, $hit_end, $hit_name,
     $hit_strand, $cigar_line, $evalue, $perc_ident, $score);

  $sth->bind_columns(
    \$dna_align_feature_id, \$seq_region_id, \$analysis_id, \$seq_region_start,
    \$seq_region_end, \$seq_region_strand, \$hit_start, \$hit_end, \$hit_name,
    \$hit_strand, \$cigar_line, \$evalue, \$perc_ident, \$score);

  my $asm_cs;
  my $cmp_cs;
  my $asm_cs_vers;
  my $asm_cs_name;
  my $cmp_cs_vers;
  my $cmp_cs_name;
  if($mapper) {
    $asm_cs = $mapper->assembled_CoordSystem();
    $cmp_cs = $mapper->component_CoordSystem();
    $asm_cs_name = $asm_cs->name();
    $asm_cs_vers = $asm_cs->version();
    $cmp_cs_name = $cmp_cs->name();
    $asm_cs_vers = $cmp_cs->version();
  }

  my $dest_slice_start;
  my $dest_slice_end;
  my $dest_slice_strand;
  my $dest_slice_length;
  if($dest_slice) {
    $dest_slice_start  = $dest_slice->start();
    $dest_slice_end    = $dest_slice->end();
    $dest_slice_strand = $dest_slice->strand();
    $dest_slice_length = $dest_slice->length();
  }

  FEATURE: while($sth->fetch()) {
    #get the analysis object
    my $analysis = $analysis_hash{$analysis_id} ||=
      $aa->fetch_by_dbID($analysis_id);

    #get the slice object
    my $slice = $slice_hash{$seq_region_id};

    if(!$slice) {
      $slice = $sa->fetch_by_seq_region_id($seq_region_id);
      $slice_hash{"ID:".$seq_region_id} = $slice;
      $sr_name_hash{$seq_region_id} = $slice->seq_region_name();
      $sr_cs_hash{$seq_region_id} = $slice->coord_system();
    }

    #
    # remap the feature coordinates to another coord system
    # if a mapper was provided
    #
    if($mapper) {
      my $sr_name = $sr_name_hash{$seq_region_id};
      my $sr_cs   = $sr_cs_hash{$seq_region_id};

      ($sr_name,$seq_region_start,$seq_region_end,$seq_region_strand) =
        $mapper->fastmap($sr_name, $seq_region_start, $seq_region_end,
                          $seq_region_strand, $sr_cs);

      #skip features that map to gaps or coord system boundaries
      next FEATURE if(!defined($sr_name));

      #get a slice in the coord system we just mapped to
      if($asm_cs == $sr_cs || ($asm_cs != $sr_cs && $asm_cs->equals($sr_cs))) {
        $slice = $slice_hash{"NAME:$sr_name:$cmp_cs_name:$cmp_cs_vers"} ||=
          $sa->fetch_by_region($cmp_cs_name, $sr_name,undef, undef, undef,
                               $cmp_cs_vers);
      } else {
        $slice = $slice_hash{"NAME:$sr_name:$asm_cs_name:$asm_cs_vers"} ||=
          $sa->fetch_by_region($asm_cs_name, $sr_name, undef, undef, undef,
                               $asm_cs_vers);
      }
    }

    #
    # If a destination slice was provided convert the coords
    # If the dest_slice starts at 1 and is foward strand, nothing needs doing
    #
    if($dest_slice && ($dest_slice_start != 1 || $dest_slice_strand != 1)) {
      if($dest_slice_strand == 1) {
        $seq_region_start = $seq_region_start - $dest_slice_start + 1;
        $seq_region_end   = $seq_region_end   - $dest_slice_start + 1;
      } else {
        my $tmp_seq_region_start = $seq_region_start;
        $seq_region_start = $dest_slice_end - $seq_region_end + 1;
        $seq_region_end   = $dest_slice_end - $tmp_seq_region_start + 1;
        $seq_region_strand *= -1;
      }

      $slice = $dest_slice;

      #throw away features off the end of the requested slice
      if($seq_region_end < 1 || $seq_region_start > $dest_slice_length) {
        next FEATURE;
      }
    }

    #finally, create the new dna align feature
    push @features, Bio::EnsEMBL::DnaDnaAlignFeature->new_fast
      ( { 'slice'         =>  $slice,
          'start'         =>  $seq_region_start,
          'end'           =>  $seq_region_end,
          'strand'        =>  $seq_region_strand,
          'hseqname'      =>  $hit_name,
          'hstart'        =>  $hit_start,
          'hend'          =>  $hit_end,
          'hstrand'       =>  $hit_strand,
          'score'         =>  $score,
          'p_value'       =>  $evalue,
          'percent_id'    =>  $perc_ident,
          'cigar_string'  =>  $cigar_line,
          'analysis'      =>  $analysis,
          'adaptor'       =>  $self,
          'dbID'          =>  $dna_align_feature_id } );
  }

  return \@features;
}

=head2 list_dbIDs

  Arg [1]    : none
  Example    : @feature_ids = @{$dna_align_feature_adaptor->list_dbIDs()};
  Description: Gets an array of internal ids for all dna align features in 
               the current db
  Returntype : list of ints
  Exceptions : none
  Caller     : ?

=cut

sub list_dbIDs {
   my ($self) = @_;

   return $self->_list_dbIDs("dna_align_feature");
}

1;


