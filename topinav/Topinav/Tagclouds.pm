package Topinav::Tagclouds;

#use base 'MainWindow';

use Imager;
use List::Util qw(first max maxstr min minstr reduce shuffle sum);

use Wx qw(:everything);
use Wx::Event qw(EVT_MOTION EVT_SIZE EVT_SLIDER EVT_TEXT EVT_KILL_FOCUS EVT_LEFT_DOWN);
use Number::Format 'format_number';

use Data::Dumper;

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

my $bbox_font=Imager::Font->new(file => 'times.ttf');

my %stopwords;
my @stopwords=split/\n/, `cat stopwords-en.txt`;
map { $stopwords{$_}="" } @stopwords;

# ================= main loader =================

sub new {
	my $class=shift;
	my %param=@_;

	my $self={};
	bless $self, $class;
	
	$self->{parent}=$param{parent};
	$self->{frame}=$param{frame};
	$self->{frame}->{parent_obj}=$self;
	
	$self->{frame}->SetBackgroundColour(Wx::Colour->new(255, 255, 255));

	$self->load_palette();
	$self->load_word_weights();
	$self->load_word_clusters();
	
	$self->show_slider();
	
	EVT_MOTION($self->{frame}, \&OnMouseOut);
	EVT_SIZE($self->{frame}, \&OnResize);

	return $self;
}

# ================= main functions =================

sub OnResize {
	my ($self, $event)=@_;
	my $obj=$self->{parent_obj};

	$max_font_size=$obj->test_word_clusters($self);
	
	$obj->clear_labels();
	if ($max_font_size > 0) {
		$obj->show_word_clusters($self);
	}
	
	my $frame=$obj->{frame};
	my $win_wd=$frame->GetSize->GetWidth;
	my $win_ht=$frame->GetSize->GetHeight;

	$textctrl_wd=$obj->{textctrl}->GetSize->GetWidth;
	$textctrl_ht=$obj->{textctrl}->GetSize->GetHeight;

	$obj->{slider}->SetClientSize($win_wd-$textctrl_wd, $textctrl_ht);
	$obj->{textctrl}->Move($win_wd-$textctrl_wd, 0);

	return 1;
}

sub load_palette {
	my $self=shift;
	my @palette=split/\n/, $self->{parent}->load_file("palette.txt");
	
	@palette=shuffle @palette;
	
	@{$self->{palette}}=();
	map { push @{$self->{palette}}, [split/ /, $_]; } @palette;
}

sub load_word_weights {
	my $self=shift;
	
	%{$self->{words}}=();
	my $i=1;
	
	open IN, "<01-words.txt";
	while (<IN>) {
		chomp;
		/ /;
		$self->{words}->{$`}=$';
		if ($i++ > $word_limit) { last; }
	}
	close IN;
}

sub load_word_clusters {
	my $self=shift;
	my $filename="guardian-filtered-sample.tree";
	
	if (@_ > 0) {
		$filename=shift;
	}
	
	%{$self->{word_cluster}}=();
	%{$self->{cluster_word}}=();
	
	my $min_weight=10000;
	my $max_weight=0;
	
	my $max_cluster=0;
	
	open IN, "<$filename";
	while (<IN>) {
		chomp;
		if (/^[0-9]/) {
			my ($coord, $rank, $word, $weight)=split/ /, $_;
			$word=substr($word, 1, -1);
			$coord=~/:/;
			
			if (exists $self->{words}->{$word}) {
				$self->{word_cluster}->{$word}=$`;
				$self->{cluster_word}->{$`}->{$word}="";
				
				$max_cluster=$`;

				if ($self->{words}->{$word} > $max_weight) { $max_weight=$self->{words}->{$word}; }
				if ($self->{words}->{$word} < $min_weight) { $min_weight=$self->{words}->{$word}; }
			}
		}
	}
	close IN;
	
	for my $word (keys %{$self->{word_cluster}}) {
		my $weight=$self->{words}->{$word};
		my $rel_font_size=($weight-$min_weight)/($max_weight-$min_weight);
		my $abs_font_size=$rel_font_size*($max_font_size-$min_font_size) + $min_font_size;
		
		$self->{words}->{$word}=int($abs_font_size);
	}
}

sub test_word_clusters {
	my $self=shift;
	my $frame=$self->{frame};
	
	my @words=sort keys %{$self->{word_cluster}};
	if (@words == 0) { return 10; }
	
	my $win_ht=$frame->GetSize->GetHeight - $textctrl_ht - $statusbar_ht;
	my $sugg_max_font_size;
	
	if (exists $self->{last_height}) {
		my $factor=$win_ht/$self->{last_height};
		$sugg_max_font_size=$max_font_size*$factor;
	} else {
		$sugg_max_font_size=$max_font_size;
	}
	
	my $new_win_ht=$self->font_size_to_height($frame, $sugg_max_font_size);
	
	my $lower_ht_factor=0.8;
	my $upper_ht_factor=1.1;
	
	while (!($win_ht * $lower_ht_factor <= $new_win_ht && $new_win_ht <= $win_ht * $upper_ht_factor)) {
		#print STDERR "($new_win_ht < $win_ht * $lower_ht_factor) { $sugg_max_font_size\n";
		
		if ($new_win_ht > $win_ht * $upper_ht_factor) {
			$sugg_max_font_size-=1;
		} elsif ($new_win_ht < $win_ht * $lower_ht_factor) {
			$sugg_max_font_size+=1;
		}
		
		if ($new_win_ht == $self->font_size_to_height($sugg_max_font_size)) {
			$sugg_max_font_size=0;
			last;
		}
		
		$new_win_ht=$self->font_size_to_height($sugg_max_font_size);
	}
	
	#print STDERR "($new_win_ht, $win_ht)\n";
	
	for my $word (keys %{$self->{words}}) {
		$self->{words}->{$word}*=$sugg_max_font_size/$max_font_size;
	}
	
	return $sugg_max_font_size;
}

sub font_size_to_height {
	my $self=shift;
	my $sugg_max_font_size=shift;
	my $frame=$self->{frame};
	my @words=sort keys %{$self->{word_cluster}};
	
	my $size_factor=$sugg_max_font_size/$max_font_size;
	
	my $x=$margin;
	my $y=$margin+$textctrl_ht;
	
	my $max_ht=0;
	my $win_wd=$frame->GetSize->GetWidth;
	
	for my $word (@words) {
		my $font_size=$self->{words}->{$word}*$size_factor;
		my $bbox=$bbox_font->bounding_box(string => $word, size => $font_size);

		my $wd=$bbox->total_width;
		my $ht=$bbox->text_height;

		if ($ht > $max_ht) { $max_ht=$ht; }

		if ($x + $wd*$word_space_factor + $margin > $win_wd) {
			$x=$margin;
			$y+=$max_ht * $word_space_factor;
			$max_ht=0;
		}
		$x+=$wd*$word_space_factor;
	}
	
	return $y+$max_ht+$margin;
}

sub show_word_clusters {
	my $self=shift;
	my $frame=$self->{frame};
	my @words=sort keys %{$self->{word_cluster}};
	
	my $x=$margin;
	my $y=$margin+$textctrl_ht;
	
	my $max_ht=0;
	my $color_count=@{$self->{palette}};
	
	my $win_wd=$frame->GetSize->GetWidth;
	my $win_ht=$frame->GetSize->GetHeight - $textctrl_ht - $statusbar_ht;
	
	$self->{last_height}=$win_ht;
	
	for my $word (@words) {
		my $font_size=$self->{words}->{$word};
		my $font_color=$self->{word_cluster}->{$word} % $color_count;
		
		my ($r, $g, $b)=@{$self->{palette}->[$font_color]};
		my ($wd, $ht)=(0, 0);
		
		($self->{labels}->{$word}, $wd, $ht)=$self->show_label($word, $x, $y, $font_size, $r, $g, $b);
		if ($ht > $max_ht) { $max_ht=$ht; }

		if ($x + $wd*$word_space_factor + $margin > $win_wd) {
			$x=$margin;
			$y+=$max_ht * $word_space_factor;
			$max_ht=0;
			
			$self->{labels}->{$word}->Move($x, $y);
		}
		$x+=$wd*$word_space_factor;
	}
}

sub show_label {
	my ($self, $text, $pos_x, $pos_y, $size, $r, $g, $b)=@_;
	my $frame=$self->{frame};

	my $label=Wx::StaticText->new($frame, -1, $text, [$pos_x, $pos_y]);
	
	EVT_MOTION($label, \&OnHover);
	EVT_LEFT_DOWN($label, \&OnClick);
	my $font=Wx::Font->new($size, wxMODERN, wxNORMAL, wxNORMAL, 0, 'Times');

	$label->SetFont($font);
	$label->SetForegroundColour(Wx::Colour->new($r, $g, $b));
	
	my $bbox=$bbox_font->bounding_box(string => $text, size => $size);

	my $wd=$bbox->total_width;
	my $ht=$bbox->text_height;

	return ($label, $wd, $ht);
}

sub clear_labels {
	my $self=shift;
	for my $word (keys %{$self->{labels}}) {
		$self->{labels}->{$word}->Destroy();
	}
	
	%{$self->{labels}}=();
}

sub OnHover {
	my ($self, $event) = @_;

	my $frame=$self->GetParent;
	my $obj=$frame->{parent_obj};
	
	my $word_cluster=$obj->{word_cluster};
	my $palette=$obj->{palette};
	my $labels=$obj->{labels};

	my $label=$self->GetLabel;
	my $cluster=$word_cluster->{$label};
	
	my $color_count=@$palette;

	$obj->{hover_cluster}=$cluster;

	my $factor_light=1.1;
	my $factor_dark=2;

	for my $word (keys %$word_cluster) {
		my $this_word_cluster=$word_cluster->{$word};
		my $font_size=$obj->{words}->{$word};

		my $font_color=$this_word_cluster % $color_count;
		my ($r, $g, $b)=@{$palette->[$font_color]};
		
		if ($this_word_cluster == $cluster) {
			my $font=Wx::Font->new($font_size, wxMODERN, wxNORMAL, wxBOLD, 0, 'Times');
			
			($r, $g, $b)=set_rgb_alpha($r, $g, $b, 0, 0.3);
			
			$labels->{$word}->SetFont($font);
			$labels->{$word}->SetForegroundColour(Wx::Colour->new($r, $g, $b));
		} else {
			my $font=Wx::Font->new($font_size/1.5, wxMODERN, wxNORMAL, wxNORMAL, 0, 'Times');
			
			($r, $g, $b)=set_rgb_alpha($r, $g, $b, 255, 0.5);

			$labels->{$word}->SetFont($font);
			$labels->{$word}->SetForegroundColour(Wx::Colour->new($r, $g, $b));
		}
	}
}

sub show_slider {
	my $self=shift;
	my $frame=$self->{frame};
	
	my $win_wd=$self->get_window_width;
	my $win_ht=$self->get_window_height;
	
	$self->{slider}=Wx::Slider->new($frame, -1, 1000, 0, 10000);
	$self->{textctrl}=Wx::TextCtrl->new($frame, -1, "");
		
	EVT_SLIDER($self->{parent}, $self->{slider}, \&OnSlider);
	EVT_TEXT($self->{parent}, $self->{textctrl}, \&OnSliderText);
	EVT_KILL_FOCUS($self->{textctrl}, \&SliderTextFormat);

	return;
}

sub get_window_width {
	my $self=shift;
	my $frame=$self->{frame};
	
	my $win_wd=$frame->GetSize->GetWidth;
	
	return $win_wd;
}

sub get_window_height {
	my $self=shift;
	my $frame=$self->{frame};
	
	my $win_ht=$frame->GetSize->GetHeight;
	
	return $win_ht-50;
}

sub SliderTextFormat {
	my ($self, $event) = @_;
	my $val=$self->GetValue;
	$val=~s/[,\.]//g;
	$self->SetValue(format_number($val));
}

sub OnSlider {
	my ($self, $event) = @_;
	
	if (!$self->{tagclouds}) {
		# in case of calling directly from MainWindow (on initialization)
		$self=$self->{parent};
	}
	
	my $slider_val=$self->{tagclouds}->{slider}->GetValue;
	$self->{process_file}->{sample_size}=$slider_val;
	
	$self->{tagclouds}->{textctrl}->SetValue(format_number($slider_val));
}

sub OnSliderText {
	my ($self, $event) = @_;
	
	my $text_val=$self->{tagclouds}->{textctrl}->GetValue;
	$text_val=~s/[,\.]//g;
	$self->{process_file}->{sample_size}=$text_val;
	
	$self->{tagclouds}->{slider}->SetValue($text_val);
}

sub OnClick {
	my $self=shift;
	
	#my $frame=$self->GetParent;
	#my $obj=$frame->{parent_obj}->{parent};
	
	#my $label=$self->GetLabel;
	
	#print STDERR "$label\n";
	#print STDERR Dumper $obj->{process_file}->{word_records}->{$label};
}

sub OnMouseOut {
	my $self=shift;
	my $obj=$self->{parent_obj};

	if (!exists $obj->{hover_cluster}) { return; }

	my $color_count=@{$obj->{palette}};

	for my $word (keys %{$obj->{word_cluster}}) {
		my $word_cluster=$obj->{word_cluster}->{$word};
		my $font_size=$obj->{words}->{$word};

		my $font_color=$word_cluster % $color_count;
		my ($r, $g, $b)=@{$obj->{palette}->[$font_color]};

		my $font=Wx::Font->new($font_size, wxMODERN, wxNORMAL, wxNORMAL, 0, 'Times');
		
		$obj->{labels}->{$word}->SetFont($font);
		$obj->{labels}->{$word}->SetForegroundColour(Wx::Colour->new($r, $g, $b));
	}
	
	delete $obj->{hover_cluster};
}

sub set_rgb_alpha {
	my ($r, $g, $b, $blend_with, $alpha)=@_;
	
	$r = $alpha * $blend_with + (1 - $alpha) * $r;
	$g = $alpha * $blend_with + (1 - $alpha) * $g;
	$b = $alpha * $blend_with + (1 - $alpha) * $b;
	
	return ($r, $g, $b);
}

1;
