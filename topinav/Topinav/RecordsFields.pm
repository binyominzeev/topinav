package Topinav::RecordsFields;

use Wx qw( :everything );

sub new {
	my $class=shift;
	my %param=@_;
	
	my $self = {};
	bless $self, $class;
	
	$self->{parent}=$param{parent};
	$self->{frame}=$param{frame};
	
	my $button2=Wx::Button->new($self->{frame}, -1, 'RecordsFields');
	
	return $self;
}

1;
