package TopinavBig::Diagrams;

use List::Util qw(shuffle);

use Term::ProgressBar::Simple;
use Data::Dumper;

# ================= initialize =================

my %stopwords;
my @stopwords=split/\n/, `cat stopwords-en.txt`;
map { $stopwords{$_}="" } @stopwords;

sub new {
	my $class=shift;
	my %param=@_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{parent}=$param{parent};
	$self->{frame}=$param{frame};
	
	my $button2=Wx::Button->new($self->{frame}, -1, 'Diagram');
	
	$self->{year_parser}=DateTime::Format::Strptime->new(pattern => "%Y");

	return $self;
}

sub generate_word_data {
	my $self=shift;
	
	my $process_file=$self->{parent}->{process_file};
	my $records=$process_file->{records};
	
	my %data;
	%{$self->{word_data_x}}=();
	%{$self->{word_data_y}}=();
	
	for my $record (values %$records) {
		my $this_x=$record->[$self->{axe_x}];
		my $this_z=$record->[$self->{axe_y}]; 	# nem eliras! (ld. utemterv.txt, 2016-06-29, "X,Y,Z")
		
		if (exists $self->{mod_x}) {
			if ($self->{mod_x} eq "year") {
				$this_x=$self->get_year($this_x);
			}
		}
		
		my $words=$process_file->string_to_words($this_z);
		map { $data{$_}->{$this_x}++; } @$words;
	}
	
	for my $z (keys %data) {
		for my $x (sort { $a <=> $b } keys %{$data{$z}}) {
			push @{$self->{word_data_x}->{$z}}, $x;
			push @{$self->{word_data_y}->{$z}}, $data{$z}->{$x};
		}
	}
}

sub use_clustering_file {
	my ($self, $filename)=@_;
	$self->{word_to_cluster}=$self->word_to_cluster($filename);
}

sub use_clustering_infomap {
	my $self=shift;
	
	my $process_file=$self->{parent}->{process_file};
	my $records=$process_file->{records};
	
	my %pair_score;
	
	for my $id (keys %$records) {
		my $line=join "\t", @{$records->{$id}};
		my $szavak=$process_file->string_to_words($line);

		my %szavak;
		map { $szavak{$_}="" } sort grep { !exists $stopwords{$_} } @$szavak;
		@szavak=keys %szavak;
		
		for my $i (0..$#szavak) {
			for my $j ($i+1..$#szavak) {
				my @pair=sort ($szavak[$i], $szavak[$j]);
				my $pair="$pair[0] $pair[1]";
				$pair_score{$pair}++;
			}
		}
	}
	
	$self->{word_to_cluster}=$process_file->edges_to_clusters(\%pair_score);
}

sub use_clustering_random {
	my $self=shift;
	
	my %cluster_sizes;
	for my $cluster (values %{$self->{word_to_cluster}}) {
		$cluster_sizes{$cluster}++;
	}

	my @words=shuffle(keys %{$self->{word_to_cluster}});
	my %word_to_cluster;
	my $i=1;

	for my $cluster (sort { $b <=> $a } keys %cluster_sizes) {
		my $size=$cluster_sizes{$cluster};
		
		map { $word_to_cluster{$_}=$i } @words[0..$size-1];
		@words=@words[$size..(scalar @words) - 1];
		$i++;
	}
	
	$self->{word_to_cluster}=\%word_to_cluster;
}

sub use_clustering_wordtime {
	my $self=shift;
	
	my %word_coord;
	my %coord_words;

	for my $word (keys %{$self->{word_data_x}}) {
		if (exists $stopwords{$word}) { next; }
		
		my $max_val=0;
		for my $i (0..$#{$self->{word_data_x}->{$word}}) {
			my $year=$self->{word_data_x}->{$word}->[$i];
			my $val=$self->{word_data_y}->{$word}->[$i];

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
	
	my $i=1;
	for my $coord (keys %coord_words) {
		for my $word (@{$coord_words{$coord}}) {
			$self->{word_to_cluster}->{$word}=$i;
		}
		$i++;
	}
}

sub save_word_data {
	my $self=shift;
	my $dirname=shift;
	
	for my $z (keys %{$self->{word_data_x}}) {
		my $filename=$z;
		$filename=~s/[\.\-']//g;
		open OUT, ">$dirname/$filename.txt";
		for my $i (0..$#{$self->{word_data_x}->{$z}}) {
			my $x=$self->{word_data_x}->{$z}->[$i];
			my $y=$self->{word_data_y}->{$z}->[$i];
			print OUT "$x $y\n";
		}
		close OUT;
	}
}

sub filter_word_data {
	my $self=shift;
	
	my @wordlist=keys %{$self->{word_data_x}};
	for my $z (@wordlist) {
		if (scalar @{$self->{word_data_x}->{$z}} < 3) {
			delete $self->{word_data_x}->{$z};
			delete $self->{word_data_y}->{$z};
		}
	}
}

sub save_word_image {
	my $self=shift;
	my $dirname=shift;

	my %options=();
	
	if (exists $self->{xlabel}) { $options{xlabel}=$self->{xlabel}; }
	if (exists $self->{ylabel}) { $options{ylabel}=$self->{ylabel}; }

	for my $z (keys %{$self->{word_data_x}}) {
		$options{output}="$dirname/$z.png";
		$options{title}="$z";	
		my $chart = Chart::Gnuplot->new(%options);
		
		my $dataSet = Chart::Gnuplot::DataSet->new(
			xdata => $self->{word_data_x}->{$z},
			ydata => $self->{word_data_y}->{$z},
			style => "linespoints",
		);

		$chart->plot2d($dataSet);
	}
}

sub word_to_cluster {
	my ($self, $filename)=@_;
	my %word_to_cluster;
	
	my $i=1;
	open IN, "<$filename";
	while (<IN>) {
		chomp;
		my @words=split/ /, $_;
		map { $word_to_cluster{$_}=$i } @words;
		$i++;
	}
	close IN;
	
	return \%word_to_cluster;
}

sub generate_data {
	my $self=shift;
	
	my $process_file=$self->{parent}->{process_file};
	my $records=$process_file->{records};
	
	my %data;
	@{$self->{data_x}}=();
	@{$self->{data_y}}=();
	
	#my %debug;
	
	for my $record (values %$records) {
		my $this_x=$record->[$self->{axe_x}];
		my $this_y=$record->[$self->{axe_y}];
		
		if (exists $self->{mod_x}) {
			if ($self->{mod_x} eq "year") {
				$this_x=$self->get_year($this_x);
			}
		}
		
		if ($self->{mod_y} eq "word_count") {
			my $words=$process_file->string_to_words($this_y);
			map { $data{$this_x}->{$_}=""; } @$words;
		} elsif ($self->{mod_y} eq "word_cluster") {
			my $words=$process_file->string_to_words($this_y);
			map { $data{$this_x}->{$self->{word_to_cluster}->{$_}}=""; } @$words;
			
			#for my $word (@$words) {
			#	$debug{$this_x}->{$self->{word_to_cluster}->{$word}}->{$word}="";
			#}
		} else {
			$data{$this_x}->{$this_y}="";
		}
	}
	
	#$self->{debug}=\%debug;
	
	# utolso ev nem erdekes
	#delete $data{2016};

	for my $x (sort { $a <=> $b } keys %data) {
		push @{$self->{data_x}}, $x;
		
		#if ($self->{mod_y} eq "count" || $self->{mod_y} eq "word_count") {
			push @{$self->{data_y}}, scalar keys %{$data{$x}};
		#}
	}
}

sub save_clustering_debug_data {
	my $self=shift;
	
	my %cluster_to_word;
	for my $word (keys %{$self->{word_to_cluster}}) {
		$cluster_to_word{$self->{word_to_cluster}->{$word}}->{$word}="";
	}
	
	my $debug=$self->{debug};

	open OUT, ">debug.txt";
	for my $year (sort keys %$debug) {
		print OUT "$year\n";
		for my $cluster (keys %{$debug->{$year}}) {
			my %inactive_words=%{$cluster_to_word{$cluster}};
			
			my @active_words=sort keys %{$debug->{$year}->{$cluster}};
			my $active_words=join " ", @active_words;
			print OUT "$active_words\n";
			
			map { delete $inactive_words{$_}; } @active_words;
			
			my @inactive_words=sort keys %inactive_words;
			my $inactive_words=join " ", @inactive_words;
			print OUT "\t$inactive_words\n";
		}
	}
	close OUT;
}

sub save_data {
	my $self=shift;
	my $filename=shift;
	
	open OUT, ">$filename";
	for my $i (0..$#{$self->{data_x}}) {
		my $x=$self->{data_x}->[$i];
		my $y=$self->{data_y}->[$i];
		print OUT "$x $y\n";
	}
	close OUT;
}

sub save_image {
	my $self=shift;
	my $filename=shift;

	my %options=(output => $filename);
	
	if (exists $self->{xlabel}) { $options{xlabel}=$self->{xlabel}; }
	if (exists $self->{ylabel}) { $options{ylabel}=$self->{ylabel}; }

	my $chart = Chart::Gnuplot->new(%options);
	my $dataSet = Chart::Gnuplot::DataSet->new(
		xdata => $self->{data_x},
		ydata => $self->{data_y},
		style => "linespoints",
	);

	$chart->plot2d($dataSet);
}

sub get_year {
	my $self=shift;
	my $date=shift;
	
	my $dt=$self->{year_parser}->parse_datetime($date);
	return $self->{year_parser}->format_datetime($dt);
}

1;

