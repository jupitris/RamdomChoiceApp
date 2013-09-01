package Web::Amazon::Cart;
use strict;
use warnings;

our $VERSION   = '0.01';
our $WSDL_DATE = '2011-08-01';
our $Locale    = 'jp';

use URI::Amazon::APA;
use LWP::UserAgent;
use XML::Simple;
use YAML::Syck;

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

sub sync_cart {
  my ($self, %params) = @_;

  $self->{cart_id} = $params{cart_id} if (exists $params{cart_id});
  $self->{hmac}    = $params{hmac} if (exists $params{hmac});

  die "Mondatory parameter 'cart_id' not defined." unless (exists $self->{cart_id});
  die "Mondatory parameter 'hmac' not defined." unless (exists $self->{hmac});

  my %query_params = (
    'Service'      => $self->{service},
    'Operation'    => 'CartGet',
    'AssociateTag' => $self->{associate_tag},
    'CartId'       => $self->{cart_id},
    'HMAC'         => $self->{hmac},
    'Version'      => $WSDL_DATE,
  );

  $self->_request(\%query_params);
}

sub create {
  my ($self, $asins_ref) = @_;

  my %query_params = (
    'Service'      => $self->{service},
    'Operation'    => 'CartCreate',
    'AssociateTag' => $self->{associate_tag},
    'Version'      => $WSDL_DATE,
  );

  for (my $i = 0; $i < scalar(@$asins_ref); $i++) {
    $query_params{'Item.' . ($i + 1) . '.ASIN'} = $asins_ref->[$i];
    $query_params{'Item.' . ($i + 1) . '.Quantity'} = 1;
  }

  $self->_request(\%query_params);
}

sub get_items {
  my ($self, %params) = @_;
  $self->sync_cart(%params);
  my @items = values %{$self->{items}};
  return \@items;
}

sub get_item_by_asin {
  my ($self, $asin, %params) = @_;
  $self->sync_cart(%params);
  return $self->{items}->{$asin};
}

sub add {
  my ($self, $asins_ref) = @_;

  my %query_params = (
    'Service'    => $self->{service},
    'Operations' => 'CartAdd',
    'CartId'     => $self->{cart_id},
    'HMAC'       => $self->{hmac},
    'Version'    => $WSDL_DATE,
  );

  for (my $i = 0; $i < scalar(@$asins_ref); $i++) {
    $query_params{'Item.' . ($i + 1) . '.ASIN'} = $asins_ref->[$i];
    $query_params{'Item.' . ($i + 1) . '.Quantity'} = 1;
  }

  $self->_request(\%query_params);
}

sub modify {
  my ($self, $cart_item_ids_ref) = @_;
  my $i = 0;

  my %query_params = (
    'Service'    => $self->{service},
    'Operations' => 'CartAdd',
    'CartId'     => $self->{cart_id},
    'HMAC'       => $self->{hmac},
    'Version'    => $WSDL_DATE,
  );

  while (my ($cart_item_id, $quantity) = each(%$cart_item_ids_ref)) {
    $query_params{'Item' . ($i + 1) . '.CartItemId'} = $cart_item_id;
    $query_params{'Item' . ($i + 1) . '.Quantity'} = $quantity;
    $i++;
  }

  $self->_request(\%query_params);
}

sub clear {
}

sub get_total_cost {
  my $self = shift;
  return $self->{total_cost};
}

sub get_purchase_url {
  my $self = shift;
  return $self->{purchase_url};
}

sub _request {
  my ($self, $params_ref) = @_;
  
  my $u = URI::Amazon::APA->new('http://ecs.amazonaws.jp/onca/xml');
  my $ua = LWP::UserAgent->new;

  $u->query_form($params_ref);
  $u->sign(
    key => $self->{access_key},
    secret => $self->{secret_access_key},
  );

  my $r = $ua->get($u);

  if ($r->is_success()) {
    my $content = XMLin(
      $r->content,
      ForceArray => ['CartItem', 'Error'],
      KeyAttr    => {'CartItem' => '+CartItemId'},
    );
    if (my $errors = $content->{'Cart'}->{'Errors'}) {
      $self->{errors} = $errors;
    }

    $self->_update_cart_data($content);
  }
}

sub _update_cart_data {
  my ($self, $content_ref) = @_;

  $self->{cart_id}        = $content_ref->{'Cart'}->{'CartId'};
  $self->{hmac}           = $content_ref->{'Cart'}->{'HMAC'};
  $self->{total_cost}     = $content_ref->{'Cart'}->{'SubTotal'}->{'Amount'};
  $self->{total_cost_fmt} = $content_ref->{'Cart'}->{'SubTotal'}->{'FormattedPrice'};
  $self->{purchase_url}   = $content_ref->{'Cart'}->{'PurchaseURL'};

  my $items = {};
  my %cart_items = %{$content_ref->{'Cart'}->{'CartItems'}->{'CartItem'}};

  foreach my $key (keys %cart_items) {
    my $asin = $cart_items{$key}->{'ASIN'} or next;

    if (exists $items->{$asin}) {
      $items->{$asin}->{quantity} += $cart_items{$key}->{'Quantity'};
    } else {
      $items->{$asin} = {
        asin         => $cart_items{$key}->{'ASIN'},
        quantity     => $cart_items{$key}->{'Quantity'},
        cart_item_id => $cart_items{$key}->{'CartItemId'},
        title        => $cart_items{$key}->{'Title'},
        price        => $cart_items{$key}->{'Price'}->{'Amount'},
        price_fmt    => $cart_items{$key}->{'Price'}->{'FormattedPrice'},
      };
    }
  }

  $self->{items} = $items;
}

1;
