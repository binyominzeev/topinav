package MainWindow;

use base 'Wx::App';

use utf8;
use Wx qw( :everything );
use Wx::Event qw(EVT_MOTION EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_MENU EVT_SIZE);

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

my $tagcloud_rel_wd=0.7;
my $tagcloud_rel_ht=0.6;

# ================= main loader =================

sub OnInit {
	my ($self)=@_;
	my $frame=Wx::Frame->new(undef, -1, 'Tagclouds', [-1, -1], [550, 550]);
	
	$self->{frame}=$frame;
	$self->{frame}->{parent_obj}=$self;
	
	my $wd=$frame->GetSize->GetWidth;
	my $ht=$frame->GetSize->GetHeight;
		
	# ==== made by wxFormDesigner ====
	
	my $rf_sizer=new Wx::BoxSizer(wxVERTICAL);
	my $rf_splitter=new Wx::SplitterWindow($frame, wxID_ANY);
	
	my $tgdia_panel=new Wx::Panel($rf_splitter, wxID_ANY);
	my $tgdia_sizer=new Wx::BoxSizer(wxVERTICAL);
	
	my $diagram_splitter=new Wx::SplitterWindow($tgdia_panel, wxID_ANY);
	my $tagcloud_panel=new Wx::Panel($diagram_splitter, wxID_ANY);
	
	my $diagram_panel=new Wx::Panel($diagram_splitter, wxID_ANY);
	
	$diagram_splitter->SplitHorizontally($tagcloud_panel, $diagram_panel);
	$tgdia_sizer->Add($diagram_splitter, 1, wxEXPAND, 5);

	$tgdia_panel->SetSizer($tgdia_sizer);

	my $rf_panel=new Wx::Panel($rf_splitter, wxID_ANY);
	
	$rf_splitter->SplitVertically($tgdia_panel, $rf_panel);
	$rf_sizer->Add($rf_splitter, 1, wxEXPAND, 5);
	
	$self->{diagram_splitter}=$diagram_splitter;
	$self->{rf_splitter}=$rf_splitter;
	
	$self->{tagcloud_panel}=$tagcloud_panel;
	$self->{diagram_panel}=$diagram_panel;
	$self->{tgdia_panel}=$tgdia_panel;
	$self->{rf_panel}=$rf_panel;
	
	$self->init_menus();

	$self->{diagram_splitter}->Unsplit();
	$self->{rf_splitter}->Unsplit();
	
	$self->{tagclouds}=new Topinav::Tagclouds(parent => $self, frame => $self->{tagcloud_panel});
	$self->{records_fields}=new Topinav::RecordsFields(parent => $self, frame => $self->{rf_panel});
	$self->{diagrams}=new Topinav::Diagrams(parent => $self, frame => $self->{diagram_panel});
	$self->{process_file}=new Topinav::ProcessFile(parent => $self, frame => $self->{diagram_panel});
	
	# initialize value
	$self->{tagclouds}->OnSlider("");
	
	$frame->CreateStatusBar();
	
	$frame->Show(1);
	$frame->Centre();
	
	#EVT_SIZE($frame, \&OnResize);

	return 1;
}

# ================= main functions =================

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

sub OnResize {
	my ($frame, $event) = @_;
	my $self=$frame->{parent_obj};
	
	my $wd=$frame->GetSize->GetWidth;
	my $ht=$frame->GetSize->GetHeight;
	
	#$self->{rf_sash}=int($wd*$tagcloud_rel_wd);
	#$self->{diagram_sash}=int($ht*$tagcloud_rel_ht);
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
