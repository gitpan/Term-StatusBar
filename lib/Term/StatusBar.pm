  package Term::StatusBar;

  $|++;
  require 5.6.0; 
  use Term::Size;
  use Term::ANSIScreen qw(:cursor :color :constants);
  $Term::ANSIScreen::AUTORESET = 1;
  our $AUTOLOAD;
  our $VERSION = do { my @r=(q$Revision: 1.8 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };


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
			prevSubText => '',
			subText => $params{subText} || '',
			subTextAlign => $params{subTextAlign} || 'left',
	  }, ref $class || $class;

      $self->setItems($params{totalItems}) if $params{totalItems};

  #################################################
  # Check if scale exceeds current width of screen 
  # and adjust accordingly. Not much we can do if 
  # label exceeds screen width
  #################################################
 
      ($self->{maxCol}, undef) = Term::Size::chars *STDOUT{IO};


  ############################################
  # Placed a workaround here for Perl 5.6.0 
  # that seems to bomb on 'no MODULE'
  ############################################

      if (do { my @r=($]=~/\d+/g); sprintf "%d."."%02d"x$#r,@r } >= 5.6001){
          no Term::Size;  ## No sense keeping this around
      }

      if (($self->{scale} + length($self->{label}) + 6) >= $self->{maxCol}){
          $self->{scale} = $self->{maxCol} - 6 - length($self->{label});
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


##################################
# Sets the subText and redisplays
##################################

  sub subText {
      my $self = shift;
      my $newSubText = shift;

      return $self->{subText} if !defined $newSubText;

      if ($newSubText ne $self->{subText}){
          $self->{subText} = $newSubText;
          $self->_printSubText;
      }
  }


##########################################
# Set totalItems, curItems, and updateInc 
##########################################

  sub setItems {
      my $self = shift;
      $self->{totalItems} = $self->{curItems} = shift if !$self->{count};

      if ($self->{totalItems} > $self->{baseScale}){
          $self->{updateInc} = int($self->{totalItems}/$self->{baseScale});
      }
  }


####################################
# Adds more text to current subText
####################################

  sub addSubText {
      my $self = shift;
      $self->{prevSubText} = $self->{subText} if !$self->{prevSubText};
      $self->{subText} = $self->{prevSubText} . shift();
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
      $self->_printSubText();

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

      $self->_printSubText;
      $self->_printPercent($percent);
  }


####################################################
# Clear the count of status bar. This is so you can
# use the same object several times and set the
# scale and totalItems differently each run
####################################################

  sub reset {
      my $self = shift;
      @$self{qw(count start prevSubText)} = (0,0,'');
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


########################################
# Calculates position to place sub-text
########################################

  sub _printSubText {
      my $self = shift;
      my $pos;

      return if !$self->{subText};

      if ($self->{subTextAlign} eq 'center'){
          my $tmp = int($self->{scale}/2) + length($self->{label});
          $pos = $tmp - int(length($self->{subText})/2);
      }
      elsif ($self->{subTextAlign} eq 'right'){
          $pos = length($self->{label}) + $self->{scale} + $self->{startCol} - length($self->{subText});
      }
      else{
          $pos = $self->{startCol}+length($self->{label});
      }

      locate $self->{startRow}+1, $self->{startCol};
      print ' 'x(length($self->{label})+$self->{scale});

      locate $self->{startRow}+1, $pos;
      print $self->{subText};
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

	startRow     - This indicates which row to place the bar at. Default is 1.
	startCol     - This indicates which column to place the bar at. Default is 1.
	label        - This places text to the left of the status bar. Default is "Status: ".
	scale        - This indicates how long the bar is. Default is 40.
	totalItems   - This tells the bar how many items are being iterated. Default is 1.
	char         - This indicates which character to use for the base bar. Default is ' ' (space).
	subText      - Text to display below the status bar
	subTextAlign - How to align subText ('left', 'center', 'right')

=head2 setItems(#)

This method does several things with the number that is passed in. First it sets 
$obj->{totalItems}, second it sets an internal counter 'curItems', last it 
determins the update increment.

This method must be used, unless you passed totalItems to the constructor.

=head2 subText('text')

Sets subText and redisplays it if necessary. If 'text' is not passed in, the current 
value of $obj->{subText} is returned. 

=head2 addSubText('text')

This takes the original value of $obj->{subText} and concats 'text' to it 
each time it is called. This might not work along side subText() since they 
both change the value of $obj->{subText}. Might cause subText() to update 
more frequently than is necessary and cause significant speed decreases in code. 

=head2 start()

This method 'draws' the initial status bar on the screen.

=head2 update()

This is really the core of the module. This updates the status bar and 
gives the appearance of movement. It really just redraws the entire thing, 
adding any new incremental updates needed.

=head2 reset()

This resets the bar's internal state and makes it available for reuse.

=head2 _printPercent()

Internal method to print the current percentage to the screen.

=head2 _printSubText()

Internal method to print the subText to the screen.

=head1 AUTHOR

Shay Harding E<lt>sharding@ccbill.comE<gt>

=head1 COPYRIGHT

This library is free software;
you may redistribute and/or modify it under the same
terms as Perl itself.

=head1 SEE ALSO

L<Term::Size>, L<Term::ANSIScreen>

=cut

