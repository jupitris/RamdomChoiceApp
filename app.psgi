use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use File::Slurp;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Amon2::Lite;
use URI::Amazon::APA;
use LWP::UserAgent;
use XML::Simple;
use YAML::Syck;
use Web::Amazon::Cart;

our $VERSION = '0.01';

# put your configuration here
sub load_config {
    my $c = shift;

    my $mode = $c->mode_name || 'development';

    +{
        'DBI' => [
            'dbi:SQLite:dbname=$mode.db',
            '',
            '',
        ],
    }
}

get '/' => sub {
    my $c = shift;
    return $c->render('index.tt' => {
        is_cart_display => 'none',
    });
};

get '/choice' => sub {
    my $c = shift;
    my $item_file = File::Spec->catfile(dirname(__FILE__), 'var', 'data', 'retrieved_items_jp_books');
    my @all_lines = read_file($item_file);
    my @entries = ();
    my $count = 0;
    my $total = 0;

    while (1) {
        my $rand = int rand @all_lines;
        my $line = $all_lines[$rand];
        my @elem = split(/\t/, $line);
        my $price = $elem[3];

        if ($price ne "" && $price <= (5000 - $total)) {
            $total += $price;
            while ($price =~ s/(.*\d)(\d\d\d)/$1,$2/) {};
            push(@entries, {asin => $elem[0], title => $elem[1], price => $price});
        }

        last if ($total > 4000 && $total <= 5000);
    }

    return $c->render('index.tt' => {
        entries => \@entries,
        is_cart_display => 'block',
    });
};

get '/add_cart' => sub {
    my $c = shift;
    my @asins = $c->req->param('asin');

    my $config_file = File::Spec->catfile(dirname(__FILE__), 'config', 'amazon_setting.yaml');
    my $setting = YAML::Syck::LoadFile($config_file);

    my $cart = Web::Amazon::Cart->new(
      access_key => $setting->{access_key},
      secret_access_key => $setting->{secret_access_key},
      associate_tag => $setting->{associate_tag},
      locale => 'jp',
    );
    $cart->create(\@asins);

    my $purchase_url = $cart->get_purchase_url;
    return $c->redirect($purchase_url);
};

# load plugins
__PACKAGE__->load_plugin('Web::CSRFDefender');
# __PACKAGE__->load_plugin('DBI');
# __PACKAGE__->load_plugin('Web::FillInFormLite');
# __PACKAGE__->load_plugin('Web::JSON');

__PACKAGE__->enable_session();

__PACKAGE__->to_app(handle_static => 1);

__DATA__

@@ index.tt
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>RamdomChoiceApp</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.8.0/jquery.min.js"></script>
    <script type="text/javascript" src="[% uri_for('/static/js/main.js') %]"></script>
    <!--link rel="stylesheet" href="http://twitter.github.com/bootstrap/1.4.0/bootstrap.min.css"-->
    <link rel="stylesheet" href="[% uri_for('/static/css/main.css') %]">
</head>
<body>
    <div class="container">
        <header><h1>Push button!</h1></header>
        <section class="row">
            <form method="get" action="/choice">
                <input type="image" src="[% uri_for('/static/img/Inception-button.jpg') %]" />
            </form>
            <form method="get" action="/add_cart">
            <ul>
            [% FOR entry IN entries %]
                <li>[% entry.asin %] | [% entry.title %] | [% entry.price %]</li>
                <input type="hidden" name="asin" value="[% entry.asin %]" />
            [% END %]
            </ul>
            <input type="image" src="[% uri_for('/static/img/material_77_1_m.png') %]" style="display:[% is_cart_display %]"/>
            </form>
        </section>
        <section class="row">
            <ol>
                <li>First, you must push the red button.</li>
                <li>Second, you push cart button if you like showed items.</li>
                <li>Last, move amazon's site, and checkout items if you like.</li>
                <li>This is amazon.co.jp only.</li>
            </ol>
        </section>
        <footer>Powered by <a href="http://amon.64p.org/">Amon2::Lite</a></footer>
    </div>
</body>
</html>

@@ /static/js/main.js

@@ /static/css/main.css
footer {
    text-align: right;
}
