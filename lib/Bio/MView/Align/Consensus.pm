# Copyright (C) 1997-2018 Nigel P. Brown

###########################################################################
package Bio::MView::Align::Consensus;

use Bio::MView::Option::Parameters;  #for $PAR
use Bio::MView::Colormap;
use Bio::MView::Groupmap;
use Bio::MView::Align::Sequence;

@ISA = qw(Bio::MView::Align::Sequence);

use strict;
use vars qw($Group_Any);

#hardwire the consensus line symcolor
my $SYMCOLOR = $Bio::MView::Colormap::Colour_Black;

my $Group             = $Bio::MView::Groupmap::Group;
my $Group_Any         = $Bio::MView::Groupmap::Group_Any;

sub get_color_identity { my $self = shift; $self->SUPER::get_color(@_) }

#colours a row of consensus sequence.
#philosophy:
#  1. the consensus colormap is just one colour name, use that and ignore CSS.
#  2. give consensus symbols their own colour.
#  3. the consensus may be a residue name: use prevailing residue colour.
#  4. use the prevailing wildcard residue colour.
#  5. give up.
sub get_color_type {
    my ($self, $c, $mapS, $mapG) = @_;
    #warn "get_color_type($self, $c, $mapS, $mapG)\n";

    #look in group colormap
    if ($COLORMAP->has_color($mapG, $c)) {
        my ($color, $index, $trans) = $COLORMAP->get_symbol_color($mapG, $c);
	#warn "$c $mapG\{$c} [$index] [$color] [$trans]\n";
	return ($color, "$trans$index");
    }

    #colormap is preset colorname
    if ($COLORMAP->has_palette_color($mapG)) {
        my ($color, $index, $trans) = $COLORMAP->get_palette_color($mapG);
        $trans = 'T';  #ignore CSS setting
        #warn "$c $mapG\{$c} [$index] [$color] [$trans]\n";
        return ($color, "$trans$index");
    }

    #look in sequence colormap
    if ($COLORMAP->has_color($mapS, $c)) {
        my ($color, $index, $trans) = $COLORMAP->get_symbol_color($mapS, $c);
	#warn "$c $mapS\{$c} [$index] [$color] [$trans]\n";
	return ($color, "$trans$index");
    }

    #look for wildcard in sequence colormap
    if ($COLORMAP->has_color($mapS, $Group_Any)) {
        my ($color, $index, $trans) = $COLORMAP->get_symbol_color($mapS, $Group_Any);
	#warn "$c $mapS\{$Group_Any} [$index] [$color] [$trans]\n";
	return ($color, "$trans$index");
    }

    return 0;    #no match
}

#colours a row of 'normal' sequence only where there is a consensus symbol.
#philosophy:
#  1. give residues their own colour.
#  2. use the prevailing wildcard residue colour.
#  3. give up.
sub get_color_consensus_sequence {
    my ($self, $cs, $cg, $mapS, $mapG) = @_;
    my ($index, $color, $trans);

    #warn "get_color_consensus_sequence($self, $cs, $cg, $mapS, $mapG)\n";

    #lookup sequence symbol in sequence colormap
    if ($COLORMAP->has_color($mapS, $cs)) {
        my ($color, $index, $trans) = $COLORMAP->get_symbol_color($mapS, $cs);
	#warn "$cs/$cg $mapS\{$cs} [$index] [$color] [$trans]\n";
	return ($color, "$trans$index");
    }

    #lookup wildcard in sequence colormap
    if ($COLORMAP->has_color($mapS, $Group_Any)) {
        my ($color, $index, $trans) = $COLORMAP->get_symbol_color($mapS, $Group_Any);
	#warn "$cs/$cg $mapS\{$Group_Any} [$index] [$color] [$trans]\n";
	return ($color, "$trans$index");
    }

    return 0;    #no match
}

#colours a row of 'normal' sequence using colour of consensus symbol.
#philosophy:
#  1. give residues the colour of the consensus symbol.
#  2. the consensus may be a residue name: use prevailing residue colour.
#  3. use the prevailing wildcard residue colour.
#  4. give up.
sub get_color_consensus_group {
    my ($self, $cs, $cg, $mapS, $mapG) = @_;
    my ($index, $color, $trans);

    #warn "get_color_consensus_group($self, $cs, $cg, $mapS, $mapG)\n";

    #lookup group symbol in group colormap
    if ($COLORMAP->has_color($mapG, $cg)) {
        my ($color, $index, $trans) = $COLORMAP->get_symbol_color($mapG, $cg);
	#warn "$cs/$cg $mapG\{$cg} [$index] [$color] [$trans]\n";
	return ($color, "$trans$index");
    }

    #lookup group symbol in sequence colormap
    if ($COLORMAP->has_color($mapS, $cg)) {
        my ($color, $index, $trans) = $COLORMAP->get_symbol_color($mapS, $cg);
	#warn "$cs/$cg $mapS\{$cg} [$index] [$color] [$trans]\n";
	return ($color, "$trans$index");
    }

    #lookup wildcard in SEQUENCE colormap
    if ($COLORMAP->has_color($mapS, $Group_Any)) {
        my ($color, $index, $trans) = $COLORMAP->get_symbol_color($mapS, $Group_Any);
	#warn "$cs/$cg $mapS\{$Group_Any} [$index] [$color] [$trans]\n";
	return ($color, "$trans$index");
    }

    return 0;    #no match
}

sub tally {
    my ($gname, $col, $gaps) = (@_, 1);
    my ($score, $class, $sym, $depth) = ({});

    if (! defined $gname) {
        $gname = Bio::MView::Groupmap::get_default_groupmap;
    }

    if (! exists $Group->{$gname}) {
	die "Bio::MView::Align::Consensus::tally: unknown consensus group '$gname'\n";
    }

    #warn "tally: $gname\n";

    my $group = $Group->{$gname}->[0];

    #initialise tallies
    foreach $class (keys %$group) { $score->{$class} = 0 }

    #select score normalization
    if ($gaps) {
	#by total number of rows (sequence + non-sequence)
	$depth = @$col;
    } else {
	#by rows containing sequence in this column
	$depth = 0;
	map { $depth++ if Bio::MView::Sequence::is_char(0, $_) } @$col;
    }
    #warn "($group, [@$col], $gaps, $depth)\n";

    #empty column? use gap symbol
    if ($depth < 1) {
	$score->{''} = 100;
	return $score;
    }

    #tally class scores by column symbol (except gaps), which is upcased
    foreach $class (keys %$group) {
	foreach $sym (@$col) {
	    next    unless Bio::MView::Sequence::is_char(0, $sym) or $gaps;
	    $score->{$class}++    if exists $group->{$class}->[1]->{uc $sym};
	}
	$score->{$class} = 100.0 * $score->{$class} / $depth;
    }
    $score;
}

sub consensus {
    my ($tally, $gname, $threshold, $ignore) = @_;
    my ($class, $bstclass, $bstscore, $consensus, $i, $score);

    if (! defined $gname) {
        $gname = Bio::MView::Groupmap::get_default_groupmap;
    }

    if (! exists $Group->{$gname}) {
	die "Bio::MView::Align::Consensus::tally: unknown consensus group '$gname'\n";
    }

    my $group = $Group->{$gname}->[0];

    $consensus = '';

    #iterate over all columns
    for ($i=0; $i<@$tally; $i++) {
	
	($score, $class, $bstclass, $bstscore) = ($tally->[$i], "", undef, 0);
	
	#iterate over all allowed subsets
	foreach $class (keys %$group) {

	    next    if $class eq $Group_Any; #wildcard
	
	    if ($class ne '') {
		#non-gap classes: may want to ignore certain classes
		next if $ignore eq 'singleton' and $class eq $group->{$class}->[0];
		
		next if $ignore eq 'class'     and $class ne $group->{$class}->[0];
	    }
	
	    #choose smallest class exceeding threshold and
	    #highest percent when same size
	
	    #warn "[$i] $class, $score->{$class}\n";

	    if ($score->{$class} >= $threshold) {
		
		#first pass
		if (! defined $bstclass) {
		    $bstclass = $class;
		    $bstscore = $score->{$class};
		    next;
		}
		
		#larger? this set should be rejected
		if (keys %{$group->{$class}->[1]} >
		    keys %{$group->{$bstclass}->[1]}) {
		    next;
		}
		
		#smaller? this set should be kept
		if (keys %{$group->{$class}->[1]} <
		    keys %{$group->{$bstclass}->[1]}) {
		    $bstclass = $class;
		    $bstscore = $score->{$class};
		    next;
		}
		
		#same size: new set has better score?
		if ($score->{$class} > $bstscore) {
		    $bstclass = $class;
		    $bstscore = $score->{$class};
		    next;
		}
	    }
	}

	if (defined $bstclass) {
	    if ($bstclass eq '' and $bstscore < 100) {
		$bstclass = $Group_Any #some non-gaps
	    }
	} else {
	    $bstclass = $Group_Any #wildcard
	}
	#warn "DECIDE [$i] '$bstclass' $bstscore [$group->{$bstclass}->[0]]\n";
	$consensus .= $group->{$bstclass}->[0];
    }
    \$consensus;
}

sub new {
    my $type = shift;
    #warn "${type}::new(@_)\n";
    if (@_ < 5) {
	die "${type}::new: missing arguments\n";
    }
    my ($from, $to, $tally, $group, $threshold, $ignore) = @_;

    if ($threshold < 50 or $threshold > 100) {
	die "${type}::new: threshold '$threshold\%' outside valid range [50..100]\n";
    }

    my $self = { %Bio::MView::Align::Sequence::Template };

    $self->{'id'}        = "consensus/$threshold\%";
    $self->{'type'}      = 'consensus';
    $self->{'from'}      = $from;
    $self->{'to'}        = $to;
    $self->{'threshold'} = $threshold;
    $self->{'group'}     = $group;

    my $string = consensus($tally, $group, $threshold, $ignore);

    #encode the new "sequence"
    $self->{'string'} = new Bio::MView::Sequence;
    $self->{'string'}->set_find_pad('\.');
    $self->{'string'}->set_find_gap('\.');
    $self->{'string'}->set_pad('.');
    $self->{'string'}->set_gap('.');
    $self->{'string'}->insert([$string, $from, $to]);

    bless $self, $type;

    $self->reset_display;

    $self;
}

sub color_by_type {
    my $self = shift;

    return unless $self->{'type'} eq 'consensus';

    my $kw = $PAR->as_dict;

    my ($color, $end, $i, $cg, @tmp) = ($self->{'display'}->{'range'});

    push @$color, 1, $self->length, 'color' => $kw->{'symcolor'};

    #warn "color_by_type($self) 1=$kw->{'aln_colormap'} 2=$kw->{'con_colormap'}\n";

    for ($end=$self->length+1, $i=1; $i<$end; $i++) {

	$cg = $self->{'string'}->raw($i);
	
	#warn "[$i]= $cg\n";

	#white space: no color
	next    if $self->{'string'}->is_space($cg);

	#gap: gapcolour
	if ($self->{'string'}->is_non_char($cg)) {
	    push @$color, $i, 'color' => $kw->{'gapcolor'};
	    next;
	}
	
	#use symbol color/wildcard colour
	@tmp = $self->get_color_type($cg,
				     $kw->{'aln_colormap'},
				     $kw->{'con_colormap'});
	if (@tmp) {
	    if ($kw->{'css1'}) {
		push @$color, $i, 'class' => $tmp[1];
	    } else {
		push @$color, $i, 'color' => $tmp[0];
	    }
	} else {
	    push @$color, $i, 'color' => $kw->{'symcolor'};
	}
    }

    $self->{'display'}->{'paint'}  = 1;
    $self;
}

sub color_by_identity {
    my ($self, $othr) = (shift, shift);

    return unless $self->{'type'} eq 'consensus';

    my $kw = $PAR->as_dict;

    my ($color, $end, $i, $cg, @tmp) = ($self->{'display'}->{'range'});

    push @$color, 1, $self->length, 'color' => $SYMCOLOR;

    #warn "color_by_identity($self, $othr) 1=$kw->{'aln_colormap'} 2=$kw->{'con_colormap'}\n";

    for ($end=$self->length+1, $i=1; $i<$end; $i++) {

       $cg = $self->{'string'}->raw($i);

       #white space: no colour
       next    if $self->{'string'}->is_space($cg);

       #gap: gapcolour
       if ($self->{'string'}->is_non_char($cg)) {
           push @$color, $i, 'color' => $kw->{'gapcolor'};
           next;
       }

       #consensus group symbol is singleton: choose colour
       if (exists $Group->{$self->{'group'}}->[2]->{$cg}) {
           if (keys %{$Group->{$self->{'group'}}->[2]->{$cg}} == 1) {

               #refer to reference colormap NOT the consensus colormap
               @tmp = $self->get_color_identity($cg, $kw->{'aln_colormap'});

               if (@tmp) {
                   if ($kw->{'css1'}) {
                       push @$color, $i, 'class' => $tmp[1];
                   } else {
                       push @$color, $i, 'color' => $tmp[0];
                   }
               } else {
                   push @$color, $i, 'color' => $SYMCOLOR;
               }

               next;
           }
       }

       #symbol not in consensus group: use contrast colour
       push @$color, $i, 'color' => $SYMCOLOR;
    }

    $self->{'display'}->{'paint'} = 1;
    $self;
}

sub color_by_mismatch { die "function undefined\n"; }

#this is analogous to Bio::MView::Align::Row::Sequence::color_by_identity()
#but the roles of self (consensus) and other (sequence) are reversed.
sub color_by_consensus_sequence {
    my ($self, $othr) = (shift, shift);

    return unless $othr;
    return unless $othr->{'type'} eq 'sequence';

    die "${self}::color_by_consensus_sequence: length mismatch\n"
	unless $self->length == $othr->length;

    my $kw = $PAR->as_dict;

    my ($color, $end, $i, $cg, $cs, $c, @tmp) = ($othr->{'display'}->{'range'});

    push @$color, 1, $self->length, 'color' => $kw->{'symcolor'};

    #warn "color_by_consensus_sequence($self, $othr) 1=$kw->{'aln_colormap'} 2=$kw->{'con_colormap'}\n";

    for ($end=$self->length+1, $i=1; $i<$end; $i++) {

	$cg = $self->{'string'}->raw($i); $cs = $othr->{'string'}->raw($i);

	#warn "[$i]= $cg <=> $cs\n";

	#white space: no colour
	next    if $self->{'string'}->is_space($cs);
					
	#gap: gapcolour
	if ($self->{'string'}->is_non_char($cs)) {
	    push @$color, $i, 'color' => $kw->{'gapcolor'};
	    next;
	}
	
	#symbols in consensus group are stored upcased
	$c = uc $cs;

	#symbol in consensus group: choose colour
	if (exists $Group->{$self->{'group'}}->[1]->{$c}) {
	    if (exists $Group->{$self->{'group'}}->[1]->{$c}->{$cg}) {

		#colour by sequence symbol
		@tmp = $self->get_color_consensus_sequence($cs, $cg,
							   $kw->{'aln_colormap'},
							   $kw->{'con_colormap'});
		if (@tmp) {
		    if ($kw->{'css1'}) {
			push @$color, $i, 'class' => $tmp[1];
		    } else {
			push @$color, $i, 'color' => $tmp[0];
		    }
		} else {
		    push @$color, $i, 'color' => $kw->{'symcolor'};
		}

		next;
	    }
	}

        #symbol not in consensus group: use contrast colour
	push @$color, $i, 'color' => $kw->{'symcolor'};
    }

    $othr->{'display'}->{'paint'} = 1;
    $self;
}


#this is analogous to Bio::MView::Align::Row::Sequence::color_by_identity()
#but the roles of self (consensus) and other (sequence) are reversed.
sub color_by_consensus_group {
    my ($self, $othr) = (shift, shift);

    return unless $othr;
    return unless $othr->{'type'} eq 'sequence';

    die "${self}::color_by_consensus_group: length mismatch\n"
	unless $self->length == $othr->length;

    my $kw = $PAR->as_dict;

    my ($color, $end, $i, $cg, $cs, $c, @tmp) = ($othr->{'display'}->{'range'});

    push @$color, 1, $self->length, 'color' => $kw->{'symcolor'};

    #warn "color_by_consensus_group($self, $othr) 1=$kw->{'aln_colormap'} 2=$kw->{'con_colormap'}\n";

    for ($end=$self->length+1, $i=1; $i<$end; $i++) {

	$cg = $self->{'string'}->raw($i); $cs = $othr->{'string'}->raw($i);

	#warn "[$i]= $cg <=> $cs\n";
	
	#no sequence symbol: whitespace: no colour
	next    if $self->{'string'}->is_space($cs);

	#gap or frameshift: gapcolour
	if ($self->{'string'}->is_non_char($cs)) {
	    push @$color, $i, 'color' => $kw->{'gapcolor'};
	    next;
	}
	
	#symbols in consensus group are stored upcased
	$c = uc $cs;

	#symbol in consensus group: choose colour
	if (exists $Group->{$self->{'group'}}->[1]->{$c}) {
	    if (exists $Group->{$self->{'group'}}->[1]->{$c}->{$cg}) {

		#colour by consensus group symbol
		#note: both symbols passed; colormaps swapped
		@tmp = $self->get_color_consensus_group($cs, $cg,
							$kw->{'aln_colormap'},
							$kw->{'con_colormap'});
		if (@tmp) {
		    if ($kw->{'css1'}) {
			push @$color, $i, 'class' => $tmp[1];
		    } else {
			push @$color, $i, 'color' => $tmp[0];
		    }
		} else {
		    push @$color, $i, 'color' => $kw->{'symcolor'};
		}

		next;
	    }
	}
	
	#symbol not in consensus group: use contrast colour
	push @$color, $i, 'color' => $kw->{'symcolor'};
    }

    $othr->{'display'}->{'paint'} = 1;
    $self;
}


###########################################################################
1;
