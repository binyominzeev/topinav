package Topinav::Diagrams;

use Wx qw( :everything );
use Chart::Gnuplot;

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
		#title => "Plotting a line from Perl arrays",
		style => "linespoints",
	);

	$chart->plot2d($dataSet);
}

sub generate_data {
	my $self=shift;
	my $records=$self->{parent}->{process_file}->{records};
	
	my %data;
	@{$self->{data_x}}=();
	@{$self->{data_y}}=();
	
	for my $record (values %$records) {
		my $this_x=$record->[$self->{axe_x}];
		my $this_y=$record->[$self->{axe_y}];
		
		if (exists $self->{mod_x}) {
			if ($self->{mod_x} eq "year") {
				$this_x=$self->get_year($this_x);
			}
		}
		
		$data{$this_x}->{$this_y}="";
	}

	for my $x (sort { $a <=> $b } keys %data) {
		push @{$self->{data_x}}, $x;
		
		if ($self->{mod_y} eq "count") {
			push @{$self->{data_y}}, scalar keys %{$data{$x}};
		}
	}
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

sub get_year {
	my $self=shift;
	my $date=shift;
	
	my $dt=$self->{year_parser}->parse_datetime($date);
	return $self->{year_parser}->format_datetime($dt);
}

1;

$diagrams->{axe_x}=1;
$diagrams->{mod_x}="year";

$diagrams->{axe_y}=0;
$diagrams->{mod_y}="count";
