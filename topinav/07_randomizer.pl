#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;
use List::Util qw(shuffle);

my $input_filename="so-time-clusters.txt";
my $output_filename="so-random-clusters.txt";

my %words;
my %cluster_sizes;

open IN, "<$input_filename";
while (<IN>) {
	chomp;
	my @words=split/ /, $_;
	
	my $cluster_size=scalar @words;
	if (!exists $cluster_sizes{$cluster_size}) {
		$cluster_sizes{$cluster_size}=1;
	} else {
		$cluster_sizes{$cluster_size}++;
	}
	
	map { $words{$_}="" } @words;
}
close IN;

my @words=shuffle(keys %words);

open OUT, ">$output_filename";
for my $cluster_size (sort { $b <=> $a } keys %cluster_sizes) {
	my $count=$cluster_sizes{$cluster_size};
	for (1..$count) {
		my @a=@words[0..$cluster_size-1];
		@words=@words[$cluster_size..(scalar @words) - 1];
		print OUT join " ", @a;
		print OUT "\n";
	}
}
close OUT;
