# -*- perl -*-
# Copyright (C) 1996-2015 Nigel P. Brown
# $Id: blastn.pm,v 1.11 2013/09/09 21:31:05 npb Exp $

###########################################################################
package NPB::Parse::Format::BLAST1::blastn;

use strict;

use vars qw(@ISA);

@ISA = qw(NPB::Parse::Format::BLAST1);

my $RANK_NONE    = '^\s*\*\*\* NONE';
my $RANK_CUT     = 60;


###########################################################################
package NPB::Parse::Format::BLAST1::blastn::HEADER;

use vars qw(@ISA);

@ISA = qw(NPB::Parse::Format::BLAST::HEADER);


###########################################################################
package NPB::Parse::Format::BLAST1::blastn::RANK;

use vars qw(@ISA);
use NPB::Parse::Regexps;

@ISA = qw(NPB::Parse::Format::BLAST::RANK);

sub new {
    my $type = shift;
    if (@_ < 2) {
	#at least two args, ($offset, $bytes are optional).
	NPB::Message::die($type, "new() invalid argument list (@_)");
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new NPB::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new NPB::Parse::Record_Stream($self);

    #column headers
    $self->{'header'} = $text->scan_lines(4);

    #ranked search hits
    $self->{'hit'}    = [];

    while (defined ($line = $text->next_line)) {
	
	#blank line or empty record: ignore
        next    if $line =~ /$NPB::Parse::Format::BLAST1::NULL/o;

	#GCG annotation: ignore
        next    if $line =~ /$NPB::Parse::Format::BLAST::GCG_JUNK/o;

	#empty ranking: done
        last    if $line =~ /$RANK_NONE/o;

	chomp $line;

	#excise variable length description and append it
	my $tmp = substr($line, 0, $RANK_CUT);
	if ($tmp =~ /^\s*([^\s]+)(.*)/) {
	    $line = $1 . substr($line, $RANK_CUT) . $2;
	}

	if ($line =~ /\s*
	    ([^\s]+)                          #id
	    \s+
	    ($RX_Uint)                        #score
	    \s+
	    ($RX_Ureal)                       #p-value
	    \s+
	    ($RX_Uint)                        #n fragments
	    \s*
	    \!?                               #GCG junk
	    \s*
	    (.*)                              #summary
	    /xo) {

	    $self->test_args($line, $1, $2, $3, $4); #ignore $5
	    
	    push @{$self->{'hit'}}, 
	    {
	     'id'      => NPB::Parse::Record::clean_identifier($1),
	     'score'   => $2,
	     'p'       => $3,
	     'n'       => $4,
	     'summary' => NPB::Parse::Record::strip_trailing_space($5),
	    };

	    next;
	}
	
	#default
	$self->warn("unknown field: $line");
    }
    $self;
}


###########################################################################
package NPB::Parse::Format::BLAST1::blastn::MATCH;

use vars qw(@ISA);

@ISA = qw(NPB::Parse::Format::BLAST::MATCH);


###########################################################################
package NPB::Parse::Format::BLAST1::blastn::MATCH::SUM;

use vars qw(@ISA);

@ISA = qw(NPB::Parse::Format::BLAST::MATCH::SUM);


###########################################################################
package NPB::Parse::Format::BLAST1::blastn::MATCH::ALN;

use vars qw(@ISA);
use NPB::Parse::Regexps;

@ISA = qw(NPB::Parse::Format::BLAST::MATCH::ALN);

sub new {
    my $type = shift;
    if (@_ < 2) {
	#at least two args, ($offset, $bytes are optional).
	NPB::Message::die($type, "new() invalid argument list (@_)");
    }
    my ($parent, $text, $offset, $bytes) = (@_, -1, -1);
    my ($self, $line, $record);

    $self = new NPB::Parse::Record($type, $parent, $text, $offset, $bytes);
    $text = new NPB::Parse::Record_Stream($self);

    #Score line
    $line = $text->next_line;

    if ($line =~ /^\s*
	Score\s*=\s*
	($RX_Uint)                   	#score
	\s+   
	\(($RX_Ureal)\s+bits\),      	#bits
	\s+   
	Expect\s*=\s*	
	($RX_Ureal),                 	#expectation
	\s+   
	(?:Sum\sP\((\d+)\)|P)\s*=\s* 	#number of frags
	($RX_Ureal)                  	#p-value
	/xo) {
	
	$self->test_args($line, $1, $2, $3, $5);

	(
	 $self->{'score'},
	 $self->{'bits'},
	 $self->{'expect'},
	 $self->{'n'},                  #substitute 1 unless $4
	 $self->{'p'},
	) = ($1, $2, $3, defined $4?$4:1, $5);
    }
    else {
	$self->warn("expecting 'Score' line: $line");
    }
    
    #Identities line
    $line = $text->next_line;

    if ($line =~ /^\s*
	Identities\s*=\s*
	(\d+\/\d+)                      #identities fraction
	\s+				
	\((\d+)%\),                     #identities percentage
	\s+				
	Positives\s*=\s*		
	(\d+\/\d+)                      #positives fraction
	\s+				
	\((\d+)%\)                      #positives percentage
	,\s+Strand\s+=\s+		
	(\S+)\s+\/\s+(\S+)              #strand orientations
	/xo) {
	
	$self->test_args($line, $1, $2, $3, $4, $5, $6);

	(
	 $self->{'id_fraction'},
	 $self->{'id_percent'},
	 $self->{'pos_fraction'},
	 $self->{'pos_percent'},
	 $self->{'query_orient'},
	 $self->{'sbjct_orient'},
	) = ($1, $2, $3, $4, $5 eq 'Plus'?'+':'-', $6 eq 'Plus'?'+':'-');
	
	#record query orientation in MATCH list
	push @{$parent->{'orient'}->{$self->{'query_orient'}}}, $self;
	
    } else {
	$self->warn("expecting 'Identities' line: $line");
    }

    $self->parse_alignment($text);

    $self;
}

sub print_data {
    my ($self, $indent) = (@_, 0);
    my $x = ' ' x $indent;
    $self->SUPER::print_data($indent);
    printf "$x%20s -> %s\n",  'score',        $self->{'score'};
    printf "$x%20s -> %s\n",  'bits',         $self->{'bits'};
    printf "$x%20s -> %s\n",  'expect',       $self->{'expect'};
    printf "$x%20s -> %s\n",  'p',            $self->{'p'};
    printf "$x%20s -> %s\n",  'n',            $self->{'n'};
    printf "$x%20s -> %s\n",  'id_fraction',  $self->{'id_fraction'};
    printf "$x%20s -> %s\n",  'id_percent',   $self->{'id_percent'};
    printf "$x%20s -> %s\n",  'pos_fraction', $self->{'pos_fraction'};
    printf "$x%20s -> %s\n",  'pos_percent',  $self->{'pos_percent'};
    printf "$x%20s -> %s\n",  'query_orient', $self->{'query_orient'};
    printf "$x%20s -> %s\n",  'sbjct_orient', $self->{'sbjct_orient'};
}


###########################################################################
package NPB::Parse::Format::BLAST1::blastn::WARNING;

use vars qw(@ISA);

@ISA = qw(NPB::Parse::Format::BLAST::WARNING);


###########################################################################
package NPB::Parse::Format::BLAST1::blastn::HISTOGRAM;

use vars qw(@ISA);

@ISA = qw(NPB::Parse::Format::BLAST::HISTOGRAM);


###########################################################################
package NPB::Parse::Format::BLAST1::blastn::PARAMETERS;

use vars qw(@ISA);

@ISA = qw(NPB::Parse::Format::BLAST::PARAMETERS);


###########################################################################
1;
