# Copyright (C) 2015-2018 Nigel P. Brown

###########################################################################
package Bio::MView::Align::Conservation;

use Bio::MView::Align::Sequence;

@ISA = qw(Bio::MView::Align::Sequence);

use strict;

sub new {
    my $type = shift;
    #warn "${type}::new(@_)\n";
    die "${type}::new: missing arguments\n"  if @_ < 3;
    my ($from, $to, $string) = @_;

    #encode the new "sequence"
    my $sob = new Bio::MView::Sequence;
    $sob->set_find_pad(' '); $sob->set_pad(' ');
    $sob->set_find_gap(' '); $sob->set_gap(' ');
    $sob->insert([$string, $from, $to]);

    my $self = new Bio::MView::Align::Sequence('clustal', $sob);

    bless $self, $type;

    $self;
}

#override
sub is_sequence { 0 }


###########################################################################
1;
