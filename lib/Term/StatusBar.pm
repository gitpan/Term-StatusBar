  package Term::StatusBar;

  $|++;
  require 5.6.0; 
  use Term::Size;
  use Term::ANSIScreen qw(:cursor :color :constants);
  $Term::ANSIScreen::AUTORESET = 1;
  our $AUTOLOAD;
  our $VERSION = do { my @r=(q$Revision: 1.6 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };


#####################
# Object constructor
#####################
 
  sub new {
      my $class = shift;
      my (%params) = @_;

      my $self = bless{
			startRow => $params{startRow} || 1,
			startCol => $params{startCol} || 1,
			label => $params{label} || 'Status: ',
			scale => $params{scale} || 40,
			totalItems => $params{totalItems} || 1,
			char => $params{char} || ' ',
			count => 0,
			updateInc => 1,
			curItems => $params{totalItems} || 1,
			baseScale => 100,
			start => 0,
			maxCol => 0,
	  }, ref $class || $class;

      $self->setItems($params{totalItems}) if $params{totalItems};

  #################################################
  # Check if scale exceeds current width of screen
  #################################################
 
      ($self->{maxCol}, undef) = Term::Size::chars *STDOUT{IO};
      no Term::Size;
 
      if ($self->{scale} >= $self->{maxCol}){
          $self->{scale} = int($self->{maxCol}*.85);
      }

      $SIG{INT} = \&{__PACKAGE__."::sigint"};

      return $self;
  }


  sub DESTROY {
      RESET;
      print "\n\n";
  }


#############################################
# Just in case this isn't done in caller. We 
# need to be able to reset the display.
#############################################

  sub sigint {
      RESET;
      print "\n\n";
      exit;
  }


####################################
# Used to get/set object variables. 
####################################

  sub AUTOLOAD {
      my $self = shift;
      (my $method = $AUTOLOAD) =~ s/.*:://;
      my $val = shift;

      if (exists $self->{$method}){
          if (defined $val){
              $self->{$method} = $val;
          }
          else{
              return $self->{$method};
          }
      }
  }


##########################################
# Set totalItems, curItems, and updateInc 
##########################################

  sub setItems {
      my $self = shift;
      $self->{totalItems} = $self->{curItems} = shift if !$self->{count};

      if ($self->{totalItems} > $self->{baseScale}){
          $self->{updateInc} = $self->{totalItems}/$self->{baseScale};
      }
  }


########################
# Init object on screen
########################
 
  sub start {
      my $self = shift;

      locate $self->{startRow}, $self->{startCol};
      print ' 'x($self->{maxCol}-$self->{startCol});

      locate $self->{startRow}, $self->{startCol};
      print $self->{label};
      print WHITE REVERSE $self->{char}x$self->{scale};

      $self->_printPercent(0);
      $self->{start}++;
  }


###################################
# Updates the status bar on screen 
###################################

  sub update {
      my $self = shift;

      $self->start if !$self->{start};

  ####################################
  # Determines if an update is needed
  ####################################

      $self->{curItems}--;

      if (($self->{curItems} % $self->{updateInc})){
          return;
      }

  ######################################################
  # Figure out how to update the bar and do minor fixes 
  # to the percentage
  ######################################################

      $self->{count} += $self->{updateInc};
      locate $self->{startRow}, length($self->{label})+1;
      print WHITE REVERSE $self->{char}x$self->{scale};

      $self->{totalItems} = 1 if $self->{totalItems} == 0;
      my $percent = $self->{count}/$self->{totalItems};
      my $count = int($percent*$self->{scale});
      $percent = int($percent*100);
      $percent = 100 if $percent > 100;

  ###############################################################
  # Due to calls to int(), the numbers sometimes do not work out 
  # exactly. If the bar is suppose to be full and at 100% this 
  # makes sure it happens
  ###############################################################

      if ($self->{totalItems} - $self->{count} < $self->{updateInc}){
          $count = $self->{scale};
          $percent = 100;
      }

  ###########################################
  # Don't update the bar if we don't need to
  ###########################################
 
      if ($count){
          locate $self->{startRow}, length($self->{label})+1;
          print BLUE REVERSE $self->{char}x$count;
      }

      $self->_printPercent($percent);
  }


####################################################
# Clear the count of status bar. This is so you can
# use the same object several times and set the
# scale and totalItems differently each run
####################################################

  sub reset {
      my $self = shift;
      @$self{qw(count start)} = (0,0);
  }


###########################
# Prints percent to screen
###########################

  sub _printPercent {
      my $self = shift;
      my $percent = shift;

      locate $self->{startRow}, length($self->{label})+$self->{scale}+2;
      print WHITE "$percent%";
  }

1;
__END__

=pod

=head1 NAME

Term::StatusBar - Dynamic progress bar

=head1 SYNOPSIS

    use Term::StatusBar;

    my $status = new Term::StatusBar (
                    label => 'My Status: ',
                    totalItems => 10,  ## Equiv to $status->setItems(10)
    );

    $status->start;  ## Optional, but recommended

    doSomething(10);

    $status->reset;  ## Resets internal state
    $status->label('New Status: ');  ## Reuse current object with new data
    $status->char('|');

    doSomething(20);


    sub doSomething {
        $status->setItems($_[0]);
        for (1..$_[0]){
            sleep 1;
            $status->update;  ## Will call $status->start() if needed
        }
    }

=head1 DESCRIPTION

Term::StatusBar uses Term::ANSIScreen for cursor positioning and to give 
the 'illusion' that the bar is moving. Term::Size is used to ensure the 
bar does not extend beyond the terminal's width.

=head1 METHODS

=head2 new(parameters)

This creates a new StatusBar object. It can take several parameters:

	startRow   - This indicates which row to place the bar at. Default is 1.
	startCol   - This indicates which column to place the bar at. Default is 1.
	label      - This places text to the left of the status bar. Default is "Status: ".
	scale      - This indicates how long the bar is. Default is 40.
	totalItems - This tells the bar how many items are being iterated. Default is 1.
	char       - This indicates which character to use for the base bar. Default is ' ' (space).

=head2 setItems(#)

This method does several things with the number that is passed in. First it sets 
$obj->{totalItems}, second it sets an internal counter 'curItems', last it 
determins the update increment.

This method must be used, unless you passed totalItems to the constructor.

=head2 start()

This method 'draws' the initial status bar on the screen.

=head2 update()

This is really the core of the module. This updates the status bar and 
gives the appearance of movement. It really just redraws the entire thing, 
adding any new incremental updates needed.

=head2 reset()

This resets the bar's internal state and makes it available for reuse.

=head2 _printPercent()

Internal sub to print the current percentage to the screen.

=head1 AUTHOR

Shay Harding E<lt>sharding@ccbill.comE<gt>

=head1 COPYRIGHT

This library is free software;
you may redistribute and/or modify it under the same
terms as Perl itself.

=head1 SEE ALSO

L<Term::Size>, L<Term::ANSIScreen>

=cut

