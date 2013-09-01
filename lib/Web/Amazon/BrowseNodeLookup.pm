package Web::Amazon::BrowseNodeLookup;
use strict;
use warnings;

our $VERSION   = '0.01';
our $WSDL_DATE = '2011-08-01';
our $Locale    = 'jp';

use URI::Amazon::APA;
use List::Util;
use XML::Simple;
use YAML::Syck;
use LWP::UserAgent;
use Data::Dumper;
use Log::Minimal;
$ENV{LM_DEBUG} = 1;

sub new {
  my ($class, %options) = @_;

  die "Mondatory parameter 'associate_tag' not defined." unless (exists $options{associate_tag});
  die "Mondatory parameter 'locale' not defined." unless (exists $options{locale});
  die "Mondatory parameter 'access_key' not defined." unless (exists $options{access_key});
  die "Mondatory parameter 'secret_access_key' not defined." unless (exists $options{secret_access_key});

  my $self = {
    service => 'AWSECommerceService',
    %options,
  };

  bless $self, $class;  
}

sub lookup {
  my ($self, $node_ids_ref) = @_;

  my %query_params = (
    'Service'      => $self->{service},
    'Operation'    => 'BrowseNodeLookup',
    'AssociateTag' => $self->{associate_tag},
    'Version'      => $WSDL_DATE,
  );

  return @{$self->_request(\%query_params, $node_ids_ref)};
}

sub _request {
  my ($self, $query_params_ref, $node_ids_ref) = @_;

  my $u = URI::Amazon::APA->new('http://ecs.amazonaws.jp/onca/xml');
  my $ua = LWP::UserAgent->new;
  my @child_node_ids = ();

  foreach my $current_node_id (@$node_ids_ref) {
    chomp($current_node_id);
    $query_params_ref->{'BrowseNodeId'} = $current_node_id;
    $u->query_form($query_params_ref);
    $u->sign(
      key => $self->{access_key},
      secret => $self->{secret_access_key},
    );

    debugf("%s request start.", $current_node_id);
    my $r = $ua->get($u);

    if ($r->is_success()) {
      my $content = XMLin(
        $r->content,
        ForceArray => ['BrowseNode', 'Error'],
        KeyAttr    => {'BrowseNode' => '+BrowseNodeId'}
      );
      if (my $errors = $content->{'BrowseNodes'}->{'Request'}->{'Errors'}) {
        warnf(YAML::Syck::Dump($errors));
      }

      my $nodelist_ref = $content->{'BrowseNodes'}->{'BrowseNode'};
      
      foreach my $node_id (keys %$nodelist_ref) {
        my $child_node = $nodelist_ref->{$node_id}->{'Children'}->{'BrowseNode'};
        foreach my $child_node_id (keys %$child_node) { 
          next if (List::Util::first{$_ eq $child_node_id} @$node_ids_ref);
          push(@child_node_ids, $child_node_id);
          debugf("%s added.", $child_node_id);
        }
      }
    } else {
      critf("%s %s %s %s", $r->status_line, $r->as_string, $r->message(), $u);
    }
    debugf("%s request finished.", $current_node_id);
    sleep 1;
  }
  
  if (scalar(@child_node_ids) > 0) {
    debugf("recursive request start.");
    push(@child_node_ids, @{$self->_request($query_params_ref, \@child_node_ids)});
    debugf("recursive request finished.");
  }

  return \@child_node_ids;
}

1
