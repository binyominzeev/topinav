package MainWindow;

use base 'Wx::App';

use utf8;
use Wx qw( :everything );
use Wx::Event qw(EVT_MOTION EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_MENU EVT_SIZE EVT_SLIDER EVT_TEXT EVT_KILL_FOCUS);

use Data::Dumper;
use Number::Format 'format_number';

use Topinav::Tagclouds;
use Topinav::ProcessFile;
use Topinav::RecordsFields;
use Topinav::Diagrams;

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

# ================= main loader =================

sub OnInit {
	my ($self)=@_;
	my $frame=Wx::Frame->new(undef, -1, 'Tagclouds', [-1, -1], [550, 550]);
	
	$self->{frame}=$frame;
	$self->{frame}->{parent_obj}=$self;
	
	my $wd=$frame->GetSize->GetWidth;
	my $ht=$frame->GetSize->GetHeight;
	
	my $tagcloud_rel_wd=0.7;
	my $tagcloud_rel_ht=0.6;
	
	# ==== made by wxFormDesigner ====
	
	my $rf_sizer=new Wx::BoxSizer(wxVERTICAL);
	my $rf_splitter=new Wx::SplitterWindow($frame, wxID_ANY);
	
	my $tgdia_panel=new Wx::Panel($rf_splitter, wxID_ANY);
	my $tgdia_sizer=new Wx::BoxSizer(wxVERTICAL);
	
	my $diagram_splitter=new Wx::SplitterWindow($tgdia_panel, wxID_ANY);
	my $tagcloud_panel=new Wx::Panel($diagram_splitter, wxID_ANY);
	
	my $diagram_panel=new Wx::Panel($diagram_splitter, wxID_ANY);
	
	$diagram_splitter->SplitHorizontally($tagcloud_panel, $diagram_panel, int($ht*$tagcloud_rel_ht));
	$tgdia_sizer->Add($diagram_splitter, 1, wxEXPAND, 5);

	$tgdia_panel->SetSizer($tgdia_sizer);

	my $rf_panel=new Wx::Panel($rf_splitter, wxID_ANY);
	
	$rf_splitter->SplitVertically($tgdia_panel, $rf_panel, int($wd*$tagcloud_rel_wd));
	$rf_sizer->Add($rf_splitter, 1, wxEXPAND, 5);
	
	$self->{diagram_splitter}=$diagram_splitter;
	$self->{rf_splitter}=$rf_splitter;
	
	$self->{tagcloud_panel}=$tagcloud_panel;
	$self->{diagram_panel}=$diagram_panel;
	$self->{tgdia_panel}=$tgdia_panel;
	$self->{rf_panel}=$rf_panel;
	
	$self->init_menus();
	
	EVT_MOTION($frame, \&OnMouseOut);
	EVT_SIZE($frame, \&OnResize);

	#$self->{tagcloud}=new Topinav::Tagclouds(parent => $self, frame => $self->{tagcloud_panel});
	$self->{records_fields}=new Topinav::RecordsFields(parent => $self, frame => $self->{rf_panel});
	$self->{diagrams}=new Topinav::Diagrams(parent => $self, frame => $self->{diagram_panel});
	#$self->{process_file}=new Topinav::ProcessFile($self);
	
	$frame->Show(1);
	$frame->Centre();
	
	return 1;
}

# ================= main functions =================


sub __set_properties {
    my $self = shift;
    # begin wxGlade: MyFrame1::__set_properties
    $self->SetTitle(_T("frame_2"));
    $self->SetSize(Wx::Size->new(20, 25));
    # end wxGlade
}

sub __do_layout {
    my $self = shift;
    # begin wxGlade: MyFrame1::__do_layout
    $self->{my_sizer} = Wx::BoxSizer->new(wxVERTICAL);
    $self->{tgdia_sizer} = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->{tgdia_splitter}->SplitHorizontally($self->{tagcloud_pane}, $self->{diagram_pane}, );
    $self->{tgdia_sizer}->Add($self->{tgdia_splitter}, 1, 0, 0);
    $self->{tgdia_pane}->SetSizer($self->{tgdia_sizer});
    $self->{main_splitter}->SplitVertically($self->{tgdia_pane}, $self->{rf_pane}, );
    $self->{my_sizer}->Add($self->{main_splitter}, 1, 0, 0);
    $self->SetSizer($self->{my_sizer});
    $self->{my_sizer}->SetSizeHints($self);
    $self->Layout();
    $self->Centre();
    # end wxGlade
}

sub show_slider {
	my $self=shift;
	#my $parent_frame=$self->{parent_frame};
	my $frame=$self->{frame};
	
	my $win_wd=$self->get_window_width;
	my $win_ht=$self->get_window_height;
	
	$self->{slider}=Wx::Slider->new($frame, -1, 1000, 0, 10000);
	$self->{textctrl}=Wx::TextCtrl->new($frame, -1, "");
	
	$self->OnSlider("");
	
	$frame->CreateStatusBar();
	
	EVT_SLIDER($self, $self->{slider}, \&OnSlider);
	EVT_TEXT($self, $self->{textctrl}, \&OnSliderText);
	EVT_KILL_FOCUS($self->{textctrl}, \&SliderTextFormat);

	return;
}

sub SliderTextFormat {
	my ($self, $event) = @_;
	my $val=$self->GetValue;
	$val=~s/[,\.]//g;
	$self->SetValue(format_number($val));
}

sub OnSlider {
	my ($self, $event) = @_;
	my $frame=$self->{frame};
	
	my $slider_val=$self->{slider}->GetValue;
	$self->{process_file}->{sample_size}=$slider_val;
	
	$self->{textctrl}->SetValue(format_number($slider_val));
}

sub OnSliderText {
	my ($self, $event) = @_;
	my $frame=$self->{frame};
	
	my $text_val=$self->{textctrl}->GetValue;
	$text_val=~s/[,\.]//g;
	$self->{process_file}->{sample_size}=$text_val;
	
	$self->{slider}->SetValue($text_val);
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

sub init_menus {
	my $self=shift;
	my $frame=$self->{frame};
	
	# Recent menu
	my $recent_menu=Wx::Menu->new();
	$recent_menu->Append(2, "(Empty)");
	$recent_menu->Enable(2, 0);
	
	# Create menus
	my $file_menu=Wx::Menu->new();
	$file_menu->Append(wxID_NEW, "New session");
	$file_menu->Append(wxID_OPEN, "Load session");
	$file_menu->AppendSubMenu($recent_menu, "Load recent");
	$file_menu->Append(wxID_SAVE, "Save session");
	$file_menu->AppendSeparator();
	$file_menu->Append(wxID_EXIT, "E&xit\tCtrl+X");

	my $view_menu=Wx::Menu->new();
	$view_menu->Append(1, "&Fields/records\tF2");
	$view_menu->Append(2, "&Diagrams\tF3");
	$view_menu->Append(3, "Set tagcloud &parameters\tF4");
	$view_menu->Append(4, "&Shuffle/resample\tF5");

	# Create menu bar
	my $menubar=Wx::MenuBar->new();
	$menubar->Append($file_menu, "\&File");
	$menubar->Append($view_menu, "&View");

	# Attach menubar to the window
	$frame->SetMenuBar($menubar);
	
	EVT_MENU($frame, wxID_EXIT, sub {$_[0]->Close(1)} );
	EVT_MENU($frame, wxID_OPEN, \&OnLoadDataset);
	EVT_MENU($frame, 1, \&OnFieldsRecords);
	EVT_MENU($frame, 2, \&OnDiagrams);
	EVT_MENU($frame, 4, \&OnResample);
}

sub OnFieldsRecords {
	my ($frame, $event) = @_;
	my $self=$frame->{parent_obj};
	
	if ($self->{rf_splitter}->IsSplit()) {
		$self->{rf_sash}=$self->{rf_splitter}->GetSashPosition();
		$self->{rf_splitter}->Unsplit();
	} else {
		$self->{rf_splitter}->SplitVertically($self->{tgdia_panel}, $self->{rf_panel});
		$self->{rf_splitter}->SetSashPosition($self->{rf_sash});
	}
}

sub OnDiagrams {
	my ($frame, $event) = @_;
	my $self=$frame->{parent_obj};
	
	if ($self->{diagram_splitter}->IsSplit()) {
		$self->{diagram_sash}=$self->{diagram_splitter}->GetSashPosition();
		$self->{diagram_splitter}->Unsplit();
	} else {
		$self->{diagram_splitter}->SplitHorizontally($self->{tagcloud_panel}, $self->{diagram_panel});
		$self->{diagram_splitter}->SetSashPosition($self->{diagram_sash});
	}
}

sub OnResample {
	my ($frame, $event) = @_;
	my $obj=$frame->{parent_obj};
	
	$obj->{process_file}->reload_file();
}

sub OnLoadDataset {
	my ($frame, $event) = @_;
	my $obj=$frame->{parent_obj};
	
	my $dialog = Wx::FileDialog->new(
		$frame, "Select a file", '', '',
		('All files (*.*)|*.*' ),
		wxFD_OPEN
	);

	if ($dialog->ShowModal == wxID_CANCEL) {
		print "cancel";
	} else {
		my @paths = $dialog->GetPaths;
		$obj->{process_file}->{filename}=$paths[0];
		$obj->{process_file}->reload_file();
	}
}

# ================= helper functions =================

sub load_file {
	my ($self, $filename)=@_;
	
	# windows eseten ez majd lecserelendo
	my $content=`cat $filename`;
	return $content;
}

# ================= events =================

sub OnMouseOut {
	my ($frame, $event)=@_;
	my $obj=$frame->{parent_obj};
	#$obj->{tagclouds}->OnMouseOut();
}

sub OnResize {
	my ($self, $event)=@_;
	my $obj=$self->{parent_obj};
	
	if (!exists $obj->{tagclouds}) {
		print STDERR $obj->{tagcloud_panel}->GetSize->GetHeight;
		print STDERR "\n";
		exit;
		#$obj->{tagclouds}="";
		$obj->{tagclouds}=new Topinav::Tagclouds(parent => $obj, frame => $obj->{tagcloud_panel});
		#$obj->{tagclouds}=new Topinav::Tagclouds($obj);
		
		#$obj->{records_fields}->{split}->Unsplit();
		#$obj->{diagrams}->{split}->Unsplit();
	}

	#$max_font_size=$obj->{tagclouds}->test_word_clusters($self);

	#$obj->{tagclouds}->clear_labels();
	#$obj->{tagclouds}->show_word_clusters($self);

	my $frame=$obj->{frame};
	my $win_wd=$frame->GetSize->GetWidth;
	my $win_ht=$frame->GetSize->GetHeight;

	$textctrl_wd=$obj->{textctrl}->GetSize->GetWidth;
	$textctrl_ht=$obj->{textctrl}->GetSize->GetHeight;

	$obj->{slider}->SetClientSize($win_wd-$textctrl_wd, $textctrl_ht);
	$obj->{textctrl}->Move($win_wd-$textctrl_wd, 0);
}

