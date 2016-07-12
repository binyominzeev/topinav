package TopinavBig::ProcessFile;

use Data::Dumper;

use Term::ProgressBar::Simple;

# ================= parameters =================

my $word_limit=1000;

my $min_font_size=9;
my $max_font_size=49;
#my $max_font_size=25;

my $margin=10;

my $word_space_factor=1.6;

my $textctrl_wd=100;
my $textctrl_ht=30;
my $statusbar_ht=45;

# ================= initialize =================

my %stopwords;
my @stopwords=split/\n/, `cat stopwords-en.txt`;
map { $stopwords{$_}="" } @stopwords;

# ================= main loader =================

sub new {
	my $class = shift;
	my %param=@_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{sample_size}=1000;
	
	return $self;
}

# ================= main functions =================

sub reload_file {
	my $self=shift;
	my $obj=$self->{parent};
	
	# ============== initialize / progress ==============
	
	my @stat=stat($self->{filename});
	my $byte_count=$stat[7];

	my $flags = wxPD_CAN_ABORT|wxPD_AUTO_HIDE|wxPD_APP_MODAL;
	#my $dialog=Wx::ProgressDialog->new('Loading dataset', 'Loading dataset, please wait...', $self->{sample_size}, $frame, $flags);
	
	#my $flags = wxPD_CAN_ABORT|wxPD_AUTO_HIDE;
	my $dialog=Wx::ProgressDialog->new('Loading dataset', 'Loading dataset, please wait...', $self->{sample_size}, undef, $flags);

	my $progress_val=0;
	
	# ============== test separator ==============
	
	my $separator="\t";
	my $count=$self->test_separator($self->{filename}, " ");
	if ($count == 1) {
		$separator=" ";
	} else {
		$self->test_separator($self->{filename}, "\t");
	}
	
	my $list=$obj->{records_fields}->{records_list};
	
	for my $i (1..$self->{field_count}) {
		$list->InsertColumn($i-1, "Column$i");
	}

	$frame->SetStatusText("Loading dataset...");
	
	my %word_freq;
	my %pair_score;
	my %ind_score;
	
	my $continue;
	$self->{parent}->{tagclouds}->load_palette();
	
	%{$self->{records}}=();
	%{$self->{word_records}}=();

	# ============== sample input file ==============
	
	my $i=1;

	open IN, "<$self->{filename}";
	for (1..$self->{sample_size}) {
		my $seek=int(rand($byte_count));
		seek (IN, $seek, 0);
		my $chunked_line=<IN>;
		my $line=lc <IN>;
		chomp $line;
		
		my @line=split/$separator/, $line;
		$self->{records}->{$i}=\@line;
		
		my $szavak=$self->string_to_words($line);
		
		my %szavak;
		map { $szavak{$_}="" } sort grep { !exists $stopwords{$_} } @$szavak;
		@szavak=keys %szavak;
		
		for my $szo (@szavak) {
			$word_freq{$szo}++;
			push @{$self->{word_records}->{$szo}}, $i;
		}
		
		for my $i (0..$#szavak) {
			for my $j ($i+1..$#szavak) {
				my @pair=sort ($szavak[$i], $szavak[$j]);
				my $pair="$pair[0] $pair[1]";
				$pair_score{$pair}++;
			}
		}
		
		$progress_val++;
		$i++;
		#if ($progress_val > 10000) { last; }
		
		$continue=$dialog->Update($progress_val);
		last unless $continue;
	}
	close IN;
	
	$dialog->Destroy;
	
	if (!$continue) {
		$frame->SetStatusText("Canceled.");
		return;
	}
	
	$frame->SetStatusText("Post-processing dataset...");
	
	# ============== filter by Top1000 words ==============
	
	my $i=1;
	my @words=sort { $word_freq{$b} <=> $word_freq{$a} } keys %word_freq;
	for my $word (@words) {
		if ($i++ > $word_limit) {
			delete $word_freq{$word};
		}
	}
	
	# ============== generate %ind_score based on filtered word pair list ==============
	
	for my $word_pair (sort { $pair_score{$b} <=> $pair_score{$a} } keys %pair_score) {
		$word_pair=~/ /;
		
		if (exists $word_freq{$`} && exists $word_freq{$'}) {
			$ind_score{$word_pair}=$word_freq{$`}+$word_freq{$'};
		}
	}
	
	# ============== determine min. ind score ==============
	
	my $upper_prop=0.35;
	
	my $word_pair_count=scalar keys %ind_score;
	my $upper_half_word_pair=$word_pair_count*$upper_prop;
	$i=1;

	my $min_ind_score=0;
	my $min_pair_score=0;
	
	open OUT, ">scores.txt";
	for my $word_pair (sort { $pair_score{$b} <=> $pair_score{$a} } keys %ind_score) {
		print OUT "$pair_score{$word_pair} $ind_score{$word_pair}\n";
		if ($i++ >= $upper_half_word_pair) {
			$min_ind_score=$ind_score{$word_pair};
			$min_pair_score=$pair_score{$word_pair};
			last;
		}
	}
	close OUT;
	
	# egyelore...
	my @ind_scores=sort { $a <=> $b } values %ind_score;
	$min_pair_score=2;
	$min_ind_score=$ind_scores[-1]*$upper_prop;
	
	# ============== filter %pair_score based on both scores ==============

	my @word_pairs=keys %pair_score;
	
	for my $word_pair (@word_pairs) {
		if (!exists $ind_score{$word_pair} || $pair_score{$word_pair} < $min_pair_score || $ind_score{$word_pair} < $min_ind_score) {
			delete $pair_score{$word_pair};
		}
	}
	
	#print STDERR "min_pair_score: $min_pair_score\n";
	#print STDERR "min_ind_score: $min_ind_score\n";
	
	# ============== generate Pajek file ==============
	
	my %word_id;
	my $last_word_id=1;
	
	my $pajek_filename="infomap";

	my @vertices;
	my @edges;
	for my $word_pair (keys %pair_score) {
		$word_pair=~/ /;
		
		if (!exists $word_id{$`}) {
			push @vertices, "$last_word_id \"$`\"";
			$word_id{$`}=$last_word_id++;
		}
		if (!exists $word_id{$'}) {
			push @vertices, "$last_word_id \"$'\"";
			$word_id{$'}=$last_word_id++;
		}
		
		push @edges, "$word_id{$`} $word_id{$'} $pair_score{$word_pair}";
	}
	
	open OUT, ">$pajek_filename.net";
	print OUT "*Vertices ".(scalar @vertices)."\n".
		(join "\n", @vertices)."\n";
	print OUT "*Edges ".(scalar @edges)."\n".
		(join "\n", @edges)."\n";
	close OUT;

	#print STDERR "*Vertices ".(scalar @vertices)."\n";
	#print STDERR "*Edges ".(scalar @edges)."\n";
	
	my $word_to_cluster=$self->edges_to_clusters(\%pair_score);
	
	# ============== update tagclouds ==============
	
	my $tagclouds=$self->{parent}->{tagclouds};

	%{$tagclouds->{words}}=();
	map { $tagclouds->{words}->{$_}=$word_freq{$_} } keys %word_id;
	
	#`Infomap $pajek_filename.net ./`;
	#$tagclouds->load_word_clusters("$pajek_filename.tree");
	$tagclouds->load_word_clusters($word_to_cluster);

	#unlink "$pajek_filename.net";
	#unlink "$pajek_filename.tree";
	
	$max_font_size=$tagclouds->test_word_clusters($frame);
	
	$tagclouds->clear_labels();
	$tagclouds->show_word_clusters($frame);
	
	$frame->SetStatusText("$self->{filename} loaded (".(scalar @vertices)." keywords shown).");
}

sub edges_to_clusters {
	my ($self, $pair_score)=@_;
	
	# ============== generate Pajek file ==============
	
	my %word_id;
	my $last_word_id=1;
	
	my $pajek_filename="infomap";

	my @vertices;
	my @edges;
	for my $word_pair (sort keys %$pair_score) {
		$word_pair=~/ /;
		
		if (!exists $word_id{$`}) {
			push @vertices, "$last_word_id \"$`\"";
			$word_id{$`}=$last_word_id++;
		}
		if (!exists $word_id{$'}) {
			push @vertices, "$last_word_id \"$'\"";
			$word_id{$'}=$last_word_id++;
		}
		
		push @edges, "$word_id{$`} $word_id{$'} $pair_score->{$word_pair}";
	}
	
	open OUT, ">$pajek_filename.net";
	print OUT "*Vertices ".(scalar @vertices)."\n".
		(join "\n", @vertices)."\n";
	print OUT "*Edges ".(scalar @edges)."\n".
		(join "\n", @edges)."\n";
	close OUT;

	#print STDERR "*Vertices ".(scalar @vertices)."\n";
	#print STDERR "*Edges ".(scalar @edges)."\n";
	
	# ============== run clustering ==============
	
	`Infomap $pajek_filename.net ./`;
	
	my %word_to_cluster;

	open IN, "<$pajek_filename.tree";
	while (<IN>) {
		chomp;
		if (/^[0-9]/) {
			my ($coord, $rank, $word, $weight)=split/ /, $_;
			$word=substr($word, 1, -1);
			
			my @coords=split/:/, $coord;
			pop @coords;
			my $cluster_coord=join ":", @coords;
			
			#if ($word eq "php") {
		#		print STDERR "php $cluster_coord\n";
		#	} else {
				#print STDERR "$word ";
		#	}
			
			$word_to_cluster{$word}=$cluster_coord;
		}
	}
	close IN;

	#unlink "$pajek_filename.net";
	#unlink "$pajek_filename.tree";
	
	return \%word_to_cluster;
}

sub save_sample {
	my ($self, $filename)=@_;
	
	my $records=$self->{records};
	
	open OUT, ">$filename";
	for my $i (keys %$records) {
		print OUT "$i\t";
		print OUT join "\t", @{$self->{records}->{$i}};
		print OUT "\n";
	}
	close OUT;
}

sub line_count {
	my $filename=shift;
	my $wc=`wc -l "$filename"`;
	
	$wc=~/[0-9]+/;
	return $&;
}

sub load_sample {
	my ($self, $filename)=@_;
	
	my $lc=line_count($filename);
	my $progress=new Term::ProgressBar::Simple($lc);
	
	open IN, "<$filename";
	while (<IN>) {
		chomp;
		my @a=split/\t/, $_;
		my $id=shift @a;
		
		$self->{records}->{$id}=\@a;
		$progress++;
	}
	close IN;
}

sub test_separator {
	my $self=shift;
	my $filename=shift;
	my $test_separator=shift;
	
	# op-sys dependent, to universalize
	`head -n20 $filename | tail -n10 > tmp`;
	my @lines=split/\n/, `cat tmp`;

	my %field_counts;
	for my $line (@lines) {
		my @line=split/$test_separator/, $line;
		$field_counts{scalar @line}="";
	}
	
	unlink "tmp";
	
	if (scalar keys %field_counts == 1) {
		my @field_counts=keys %field_counts;
		$self->{field_count}=$field_counts[0];
	}

	return scalar keys %field_counts;
}

sub string_to_words {
	my $self=shift;
	my $string=shift;
	
	$string=~s/\&\#x27\;/'/g;
	
	# wikipedia regexp - : elotti namespace, . utani extension kiszurese
	$string=~s/^\s*\S+?://g;
	$string=~s/\.\S+\s*$//g;
	
	my @szavak=$string=~/[\-a-zA-ZáéíóöőúüűÁÉÍÓÖŐÚÜŰ']+/g;
	return \@szavak;
}

1;
