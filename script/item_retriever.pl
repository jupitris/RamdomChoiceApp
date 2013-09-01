#!/usr/bin/perl

use strict;
use warnings;
use utf8;
binmode(STDOUT, ":utf8");
use Net::Amazon;
use Net::Amazon::Request::BrowseNode;
use FindBin;
use File::Spec;
use File::Slurp;
use lib File::Spec->catdir($FindBin::Bin, File::Spec->updir(), 'lib');
use Log::Log4perl qw(:easy);
use Data::Dumper;
use POSIX;
use Getopt::Long;
use Pod::Usage;
use Web::Amazon::ItemSearch;

Log::Log4perl->easy_init($ERROR);

my $logger = get_logger();

if ($#ARGV == -1) {
    pod2usage(2);
}

my %opt = ();
GetOptions(\%opt, 'help|h', 'list=s', 'category=s', 'man') or die ("ERROR $!");
pod2usage(1) if $opt{help} or $opt{h};
pod2usage(-verbose => 2) if $opt{man};
print $opt{man}, "\n" unless $opt{list} or $opt{category};

my $list_file = $opt{list};
my $category = $opt{category};
my $item_file = File::Spec->catfile($FindBin::Bin, File::Spec->updir(), 'var', 'data', "retrieved_items_jp_${category}");
my $config_file = File::Spec->catfile($FindBin::Bin, File::Spec->updir(), 'config', 'amazon_setting.yaml');
my $setting = YAML::Syck::LoadFile($config_file);

my $search = Web::Amazon::ItemSearch->new(
  access_key => $setting->{access_key},
  secret_access_key => $setting->{secret_access_key},
  associate_tag => $setting->{associate_tag},
  locale => 'jp',
);

my @node_list = read_file($list_file);
$search->search(browsenode => \@node_list, category => $category);
my $item_list_ref = $search->get_item_list;

open my $out, ">:utf8", $item_file
    or die "Cannot open '$item_file': $!";
foreach my $item (@$item_list_ref) {
  print $out $item;
}
close $out;

1;

__END__

=pod

=head1 NAME

item_retriever.pl -- retrieve item by using BrowseNodeID from Amazon.

=head1 SYNOPSIS

B<item_retriever.pl> [optiones...]

Options: [-h|--help|-l=list|--list=list|-c=category|--category=category|-m|--man]

=head1 OPTIONS

=over 8

=item B<-h|--help>

print help.

=item B<-l=list|--list=list>

print list.

=item B<-c=category|--category>

print category.

=item B<-m|--man>

print man.

=back

=head1 DESCRIPTION

This script is retrieving item from Amazon.

=cut

