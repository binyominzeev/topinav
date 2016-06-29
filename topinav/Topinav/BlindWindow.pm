package Topinav::BlindWindow;

use Wx qw( :everything );
use base 'Wx::Window';

sub new {
	my $class=shift;
	my %param=@_;
	
	my $self = {};
	bless $self, $class;
	
	if (!exists $param{'nochilds'}) {
		$self->{records_fields}->{records_list}=new Topinav::BlindWindow(nochilds => 1);
		$self->{frame}=new Topinav::BlindWindow(nochilds => 1);
		$self->{tagclouds}=new Topinav::BlindWindow(nochilds => 1);
	}
	
	return $self;
}

sub InsertColumn { 			return 1; }
sub SetStatusText { 		return 1; }
sub load_palette { 			return 1; }
sub load_word_clusters { 	return 1; }
sub test_word_clusters { 	return 1; }
sub show_word_clusters { 	return 1; }
sub clear_labels { 			return 1; }

1;
