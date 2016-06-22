package Topinav::RecordsFields;

use Wx qw( :everything );

sub new {
	my $class=shift;
	my %param=@_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{parent}=$param{parent};
	$self->{frame}=$param{frame};

	my $sizer=new Wx::BoxSizer(wxVERTICAL);

	$self->{records_list}=Wx::ListCtrl->new($self->{frame}, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxLC_REPORT);
	$sizer->Add($self->{records_list}, 1, wxALL|wxEXPAND, 5);
	
	$self->{frame}->SetSizer($sizer);
	$self->{frame}->Layout();
	
	return $self;
}

1;
