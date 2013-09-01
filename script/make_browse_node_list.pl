#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use FindBin;
use File::Spec;
use File::Slurp;
use lib File::Spec->catdir($FindBin::Bin, File::Spec->updir(), 'lib');
use YAML::Syck;
use Getopt::Long;
use Pod::Usage;
use Web::Amazon::BrowseNodeLookup;

if ($#ARGV == -1) {
    pod2usage(2);
}

my %opt = ();
GetOptions(\%opt, 'help|h', 'list=s', 'man') or die ("ERROR $!");
pod2usage(1) if $opt{help} or $opt{h};
pod2usage(-verbose => 2) if $opt{man};
print $opt{man}, "\n" unless $opt{list};

my $list_file = $opt{list};
my $child_list_file = File::Spec->catfile($FindBin::Bin, File::Spec->updir(), 'var', 'data', 'browse_node_child_id_jp.lst');
my $config_file = File::Spec->catfile($FindBin::Bin, File::Spec->updir(), 'config', 'amazon_setting.yaml');
my $setting = YAML::Syck::LoadFile($config_file);

my $lookup = Web::Amazon::BrowseNodeLookup->new(
  access_key => $setting->{access_key},
  secret_access_key => $setting->{secret_access_key},
  associate_tag => $setting->{associate_tag},
  locale => 'jp',
);

my @node_list = read_file($list_file);
my @child_node_ids = $lookup->lookup(\@node_list);

open my $out, '>', $child_list_file
    or die "Cannot open '$child_list_file': $!";
foreach my $child_node_id (@child_node_ids) {
  print $out "$child_node_id\n";
}
close $out;

1;

__END__

=pod

=head1 NAME

make_browse_node_list.pl -- make all BrowseNodeIDs list.

=head1 SYNOPSIS

B<make_browse_node_list.pl> [options...]

Options: [-h|--help|-l=list|--list=list|-m|--man]

=head1 OPTIONS

=over 8

=item B<-h|--help>

print help.

=item B<-l=list|--list=list>

print list.

=item B<-m|--man>

print man.

=back

=head1 DESCRIPTION

This script is making all browse node id list.

=cut
