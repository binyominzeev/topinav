#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;

use Topinav::ProcessFile;
use Topinav::BlindWindow;
use Topinav::Diagrams;

use DateTime::Format::Strptime;

# ========= local parameters =========

#my $sample_size=2000;
my $sample_size=200;
my $repetitions=1;

# ========= base classes =========

my $blind=new Topinav::BlindWindow();
my $process_file=new Topinav::ProcessFile(parent => $blind, frame => $blind);

my $diagrams_count=new Topinav::Diagrams(parent => $blind, frame => $blind);
my $diagrams_words=new Topinav::Diagrams(parent => $blind, frame => $blind);
my $diagrams_wordclust=new Topinav::Diagrams(parent => $blind, frame => $blind);

# ========= base classes =========

$diagrams_count->{parent}->{process_file}=$process_file;
$diagrams_words->{parent}->{process_file}=$process_file;
$diagrams_wordclust->{parent}->{process_file}=$process_file;

# ========= init parameters =========

$process_file->{sample_size}=$sample_size;
$process_file->{filename}="so-id-title.txt";

my %x_param=(
	axe_x => 1,
	mod_x => "year",
	xlabel => "year"
);

map { $diagrams_count->{$_}=$x_param{$_} } keys %x_param;
map { $diagrams_words->{$_}=$x_param{$_} } keys %x_param;
map { $diagrams_wordclust->{$_}=$x_param{$_} } keys %x_param;

$diagrams_count->{axe_y}=0;
$diagrams_count->{mod_y}="count";
$diagrams_count->{ylabel}="# of (sampled) elements";

$diagrams_words->{axe_y}=2;
$diagrams_words->{mod_y}="word_count";
$diagrams_words->{ylabel}="# of distinct words";

$diagrams_wordclust->{axe_y}=2;
$diagrams_wordclust->{mod_y}="word_cluster";
$diagrams_wordclust->{ylabel}="# of (temporal) word clusters";

# ========= do =========

#for my $i (1..$repetitions) {
	my $code=join'', map +(0..9,'a'..'z','A'..'Z')[rand(10+26*2)], 1..8;
	#print STDERR "$i $code\n";

	#$process_file->reload_file();
	#$process_file->save_sample("my_sample.txt");
	$process_file->load_sample("my_sample.txt");
	$diagrams_wordclust->generate_word_data();
	$diagrams_wordclust->filter_word_data();
	
	#$diagrams_wordclust->use_clustering_file("so-random-clusters.txt");
	$diagrams_wordclust->use_clustering_wordtime();
	$diagrams_wordclust->use_clustering_random();
	
	$diagrams_wordclust->generate_data();
	$diagrams_wordclust->save_data("05-3-yearly-wordclust-$code.txt");
	$diagrams_wordclust->save_image("05-3-yearly-wordclust-$code.png");
	exit;
	
	$diagrams_count->generate_data();
	$diagrams_count->save_data("05-1-yearly-records-$code.txt");
	$diagrams_count->save_image("05-1-yearly-records-$code.png");

	$diagrams_words->generate_data();
	$diagrams_words->save_data("05-2-yearly-words-$code.txt");
	$diagrams_words->save_image("05-2-yearly-words-$code.png");

	#$diagrams_wordclust->generate_data();
	$diagrams_wordclust->generate_word_data();
	$diagrams_wordclust->filter_word_data();
	$diagrams_wordclust->save_word_data("word_data_image");
	$diagrams_wordclust->save_word_image("word_data_image");
	
#}
