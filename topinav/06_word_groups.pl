#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;

my $origin=2008;

# ================= initialize =================

my %stopwords;
my @stopwords=split/\n/, `cat stopwords-en.txt`;
map { $stopwords{$_}="" } @stopwords;

# ================= do =================

my @word_files=split/\n/, `ls word_data_image/*.txt`;
my %word_coord;
my %coord_words;

for my $word_file (@word_files) {
	my @lines=split /\n/, `cat $word_file`;
	
	$word_file=~/\/(.*)\./;
	my $word=$1;
	
	if (exists $stopwords{$word}) { next; }
	
	my $max_val=0;
	for my $line (@lines) {
		my ($year, $val)=split/ /, $line;
		$word_coord{$word}->[$year-$origin]=$val;
		if ($val > $max_val) { $max_val=$val; }
	}
	
	for my $i (0..8) {
		if (exists $word_coord{$word}->[$i] && $word_coord{$word}->[$i] > $max_val / 2) {
			$word_coord{$word}->[$i]=1;
		} else {
			$word_coord{$word}->[$i]=0;
		}
	}
	my $coord=join "", @{$word_coord{$word}};
	push @{$coord_words{$coord}}, $word;
}

#print Dumper %coord_words;

open OUT, ">so-time-clusters.txt";
for my $coord (sort { scalar @{$coord_words{$b}} <=> scalar @{$coord_words{$a}} } keys %coord_words) {
	#print "$coord\t".(scalar @{$coord_words{$coord}})."\t".(join " ", sort @{$coord_words{$coord}})."\n";
	print OUT join " ", sort @{$coord_words{$coord}};
	print OUT "\n";
}
close OUT;
