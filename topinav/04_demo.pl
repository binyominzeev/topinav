#!/usr/bin/perl
use strict;
use warnings;
use Wx;

package ProgressTest;
use base 'Wx::App';

use Wx qw( :everything );
use Wx::Event qw(EVT_BUTTON);

use Time::HiRes qw(usleep);

# ================= main loader =================

sub OnInit {
	my ($self)=@_;
	
	my $frame=Wx::Frame->new(undef, -1, 'Test window', [-1, -1], [550, 550]);
	$self->{frame}=$frame;
	
	$self->{main_splitter} = Wx::SplitterWindow->new($frame, wxID_ANY);
	$self->{tgdia_pane} = Wx::Panel->new($self->{main_splitter}, wxID_ANY);
	$self->{tgdia_splitter} = Wx::SplitterWindow->new($self->{tgdia_pane}, wxID_ANY);
	$self->{tagcloud_pane} = Wx::Panel->new($self->{tgdia_splitter}, wxID_ANY);
	$self->{diagram_pane} = Wx::Panel->new($self->{tgdia_splitter}, wxID_ANY);
	$self->{rf_pane} = Wx::Panel->new($self->{main_splitter}, wxID_ANY);

	$self->{my_sizer} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{tgdia_sizer} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{tgdia_splitter}->SplitHorizontally($self->{tagcloud_pane}, $self->{diagram_pane}, );
	$self->{tgdia_sizer}->Add($self->{tgdia_splitter}, 1, 0, 0);
	$self->{tgdia_pane}->SetSizer($self->{tgdia_sizer});
	$self->{main_splitter}->SplitVertically($self->{tgdia_pane}, $self->{rf_pane}, );
	$self->{my_sizer}->Add($self->{main_splitter}, 1, 0, 0);
	$frame->SetSizer($self->{my_sizer});
	$self->{my_sizer}->SetSizeHints($frame);
	
	$frame->Show(1);
	$frame->Centre();

	return 1;
}

# ================= main functions =================

sub on_click_dialog {
	my ($self, $event) = @_;
	
	my $frame=$self->{frame};
	
	my $max=1000;
	my $flags = wxPD_CAN_ABORT|wxPD_AUTO_HIDE|wxPD_APP_MODAL|wxPD_ELAPSED_TIME|wxPD_ESTIMATED_TIME|wxPD_REMAINING_TIME;
	my $dialog=Wx::ProgressDialog->new('Loading dataset', 'Loading dataset, please wait...', $max, $frame, $flags);

	my $continue;
	foreach my $i (1..$max) {
		usleep(10);
		$continue = $dialog->Update($i);
		last unless $continue;
	}
	
	$dialog->Destroy;
}

sub on_click {
	my ($self, $event) = @_;
	
	if ($self->{split}->IsSplit()) {
		$self->{sash}=$self->{split}->GetSashPosition();
		$self->{split}->Unsplit();
	} else {
		$self->{split}->SplitHorizontally($self->{pane1}, $self->{pane2});
		$self->{split}->SetSashPosition($self->{sash});
	}
	
	return;
	
	my $progress_val=0;
	$self->{progressbar}->SetRange(2000);
	
	for (1..2000) {
		usleep(10);
		$progress_val++;
		$self->{progressbar}->SetValue($progress_val);
		$self->{progressbar}->Update();
	}
	
	return;
}

sub on_cancel {
	my ($self, $event) = @_;
	my $progress_val=0;
	$self->{progressbar}->SetRange(2000);
	
	for (1..2000) {
		usleep(10);
		$progress_val++;
		$self->{progressbar}->SetValue($progress_val);
		$self->{progressbar}->Update();
	}
	
	return;
}

# ================= main cycle =================

package main;

my $app = ProgressTest->new;
$app->MainLoop;
