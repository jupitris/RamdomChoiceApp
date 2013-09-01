package Web::Amazon::ItemSearch;
use strict;
use warnings;

our $VERSION   = '0.01';
our $WSDL_DATE = '2011-08-01';
our $Locale    = 'jp';

use URI::Amazon::APA;
use XML::Simple;
use YAML::Syck;
use LWP::UserAgent;
use Data::Dumper;
use Log::Minimal;

use constant DEFAULT_MAX_ITEM_PAGE => 10;

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

sub search {
  my ($self, %params) = @_;

  die "Mondatory parameter 'browsenode' not defined." unless (exists $params{browsenode});
  die "Mondatory parameter 'category' not defined." unless (exists $params{category});

  my %query_params = (
    'Service'       => $self->{service},
    'Operation'     => 'ItemSearch',
    'AssociateTag'  => $self->{associate_tag},
    'Version'       => $WSDL_DATE,
    'SearchIndex'   => $params{category},
    'ResponseGroup' => 'Large',
    'MaximumPrice'  => '5000',
  );
 
  if (ref($params{browsenode}) eq "ARRAY") {
    foreach my $node_id (@{$params{browsenode}})  {
      chomp($node_id);
      $query_params{'BrowseNode'} = $node_id;
      $query_params{'ItemPage'} = '1';
      $self->_request(\%query_params);
      my $total_pages = $self->{total_pages} + 0 || 0;
      next if ($total_pages <= 1);

      my $max_page;
      if ($total_pages > DEFAULT_MAX_ITEM_PAGE) {
        $max_page = DEFAULT_MAX_ITEM_PAGE;
      } else {
        $max_page = $total_pages + 0;
      }

      for (my $i = 2; $i <= $max_page; $i++) {
        $query_params{'ItemPage'} = "$i";
        $self->_request(\%query_params);
        sleep 1;
      }
      infof("search %d finished.", $node_id);
      sleep 1;
    }
  } else {
    $query_params{'BrowseNode'} = $params{browsenode};
    $self->_request(\%query_params);
  }
}

sub get_item_list {
  my $self = shift;
  return $self->{item_list};
}

sub _request {
  my ($self, $params_ref) = @_;

  my $u = URI::Amazon::APA->new('http://ecs.amazonaws.jp/onca/xml');
  my $ua = LWP::UserAgent->new;

  $u->query_form($params_ref);
  $u->sign(
    key    => $self->{access_key},
    secret => $self->{secret_access_key},
  );

  my $r = $ua->get($u);
  infof("%s", $u);

  if ($r->is_success()) {
    my $content = XMLin(
      $r->content,
      ForceArray => ['Item', 'Error'],
    );

    $self->{total_results} = $content->{Items}->{TotalResults};
    $self->{total_pages}   = $content->{Items}->{TotalPages};

    unless ($self->is_error($content)) {
      my @item_list = ();
      if (exists $self->{item_list}) {
        @item_list = @{$self->{item_list}};
      }
      my $items_ref = $content->{'Items'}->{'Item'};
  
      foreach my $item (@$items_ref) {
        my $asin        = $item->{ASIN} || '';
        my $title       = $item->{ItemAttributes}->{Title} || '';
        my $small_image = $item->{SmallImage}->{URL} || '';
        my $amount      = $item->{Offers}->{Offer}->{OfferListing}->{Price}->{Amount} || '';
        my $sales_rank  = $item->{SalesRank} || '';
        my $detail_url  = $item->{DetailPageURL} || '';
        push(@item_list, 
          "$asin\t$title\t$small_image\t$amount\t$sales_rank\t$detail_url\n");
      }
      $self->{item_list} = \@item_list;
    }
  } else {
    critf($r->status_line, $r->as_string, $r->message());
  }
}

sub is_error {
  my ($self, $response_ref) = @_;

  if (my $errors = $response_ref->{'Items'}->{'Request'}->{'Errors'}) {
    if (ref($errors->{Error}) eq "ARRAY") {
      my @errmsg = ();
      for my $e (@{$errors->{Error}}) {
        push(@errmsg, $e->{Message});
        infof("%s", $e->{Message});
      }
      $self->{messages} = \@errmsg;
    }
    return 1;
  }
  return 0;
}

1;

