package Term::StatusBar;
no warnings 'portable';

$|++;
require 5.6.0; 
use Term::Size 'chars';
use Time::HiRes qw(tv_interval gettimeofday);
our ($AUTOLOAD, $FH);
our $VERSION = do { my @r=(q$Revision: 1.3 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };


sub new {
  my ($class, %params) = @_;

  my $self = bless{
      startRow      => $params{startRow} || 1,
      startCol      => $params{startCol} || 1,
      label         => $params{label} || 'Status: ',
      scale         => $params{scale} || 40,
      totalItems    => $params{totalItems} || 1,
      char          => $params{char} || ' ',
      count         => 0,
      updateInc     => int($params{updateInc}) || 1,
      curItems      => $params{totalItems} || 1,
      baseScale     => 100,
      start         => 0,
      maxCol        => 0,
      prevSubText   => undef,
      subText       => undef,
      subTextAlign  => $params{subTextAlign} || 'left',
      reverse       => $params{reverse} || 0,
      barColor      => $params{barColor} || "\e[7;37m",
      fillColor     => $params{fillColor} || "\e[7;34m",
      barStart      => undef,
      subTextChange => undef,
      subTextLength => undef,
      fh            => $params{fh} || *STDOUT,
      precision     => $params{precision} || 0,
      showTime      => $params{showTime} || 0,
      lastTime      => undef, 
      itemAccum     => $params{totalItems} || 1,
  }, ref $class || $class;

  $FH = $self->{fh};

  $self->subText($params{subText});
  $self->{subTextLength} = length($self->{subText});

  $self->setItems($params{totalItems}) if $params{totalItems};
  $self->{barStart} = length($self->{label})+1;

  ## Check if scale exceeds current width of screen 
  ## and adjust accordingly. Not much we can do if 
  ## label exceeds screen width
  $self->{maxCol} = Term::Size::chars;

  if (($self->{scale} + $self->{barStart} + 5) >= $self->{maxCol}){
     $self->{scale} = $self->{maxCol} - 5 - $self->{barStart};
  }

  if ($self->{precision} > 4){ $self->{precision} = 4; }
  if ($self->{showTime}){ $self->{startRow}++; }

  $SIG{INT} = \&{__PACKAGE__."::sigint"};
  return $self;
}

sub DESTROY { sigint(); }


##
## Just in case this isn't done in caller. We 
## need to be able to reset the display.
##
sub sigint {
  print $FH "\n\n";
  exit;
}


##
## Used to get/set object variables. 
##
sub AUTOLOAD {
  my ($self, $val) = @_;
  (my $method = $AUTOLOAD) =~ s/.*:://;

  if (exists $self->{$method}){
    if (defined $val){
      $self->{$method} = $val;
    }
    else{
      return $self->{$method};
    }
  }
}


##
## Sets the subText and redisplays
##
sub subText {
  my ($self, $newSubText) = @_;
  return $self->{subText} if !defined $newSubText;

  if ($newSubText ne $self->{subText}){
    $self->{subText} = $newSubText;
    $self->{subTextLength} = length($newSubText);
    print $FH $self->_printSubText();
    $self->{subTextChange} = 1;
  }
  else{
    $self->{subTextChange} = 0;
  }
}


##
## Set totalItems, curItems, and updateInc 
##
sub setItems {
  my ($self, $num) = @_;

  ## Items must be > 0
  $num = 1 if !$num;
  $self->{totalItems} = $self->{curItems} = abs($num) if !$self->{count};

  if ($self->{totalItems} > $self->{baseScale}){
    $self->{updateInc} = int($self->{totalItems}/$self->{baseScale});
  }
}


##
## Adds more text to current subText
##
sub addSubText {
  my ($self, $text) = @_;
  return if !defined $text || $text eq '';

  $self->{prevSubText} = $self->{subText} if !$self->{prevSubText};
  $self->{subText} = $self->{prevSubText} . $text;
  $self->{subTextChange} = 1;
}


##
## Init object on screen
## 
sub start {
  my ($self) = @_;

  print $FH "\e[$self->{startRow};$self->{startCol}H", (' 'x($self->{maxCol}-$self->{startCol}));
  print $FH "\e[$self->{startRow};$self->{startCol}H$self->{label}";
  print $FH $self->{barColor}, ($self->{char}x$self->{scale}), "\e[0m";

  print $FH $self->_printPercent($self->{reverse}?100:0);
  print $FH $self->_printSubText();

  $self->{start}++;
}


##
## Updates approximate time
##

sub calcTime {
   my ($self) = @_;
   return if !$self->{showTime};
   my ($time);

   if (!$self->{reverse} && $self->{lastTime}){
      my $tp = tv_interval($self->{lastTime});
      my $tmp = $self->{itemAccum};
      $self->{itemAccum} = $self->{totalItems} - $self->{count};
      $tp = ($tp/($tmp-$self->{itemAccum}))*$self->{itemAccum};

      my ($hours, $mins, $secs) = ("00")x3;
      if ($tp >= 3600){
         $hours = sprintf("%02d", int($tp/3600));
         $tp -= $hours*3600;
      }
      if ($tp >= 60){
         $mins = sprintf("%02d", int($tp/60));
         $tp -= $mins*60;
      }
      if ($tp >= 1){
         $secs = sprintf("%02d", int($tp));
      }

      $time = "$hours:$mins:$secs";
   }
   else{
      $time = "00:00:00";
   }

   my $pos = int($self->{scale}/2) + $self->{barStart}-5;
   my $t = "\e[".($self->{startRow}-1).";$self->{startCol}H";
   $t .= ' 'x($self->{barStart}+$self->{scale});
   $t .= "\e[".($self->{startRow}-1).";${pos}H".$time;

   print $t;
   $self->{lastTime} = [gettimeofday];
}


##
## Updates the status bar on screen 
##
sub update {
  my ($self) = @_;
  $self->start if !$self->{start};

  $self->calcTime();

  ## Determines if an update is needed
  if ((--$self->{curItems} % $self->{updateInc})){
      return;
  }

  ## Figure out how to update the bar and do minor fixes 
  ## to the percentage
  $self->{count} += $self->{updateInc};

  my $percent = $self->{count}/$self->{totalItems};
  $percent = 1-$percent if $self->{reverse};
  my $count = int($percent*$self->{scale});
  $percent = sprintf("%.$self->{precision}f", $percent*100);

  ## Due to calls to int(), the numbers sometimes do not work out 
  ## exactly. If the bar is suppose to be full and at 100% this 
  ## makes sure it happens
  if ($self->{totalItems} - $self->{count} < $self->{updateInc}){
    $count = $self->{scale};
    $percent = $self->{reverse}?0:100;
  }

  my $startCol = $self->{barStart}+$count;
  my $bar;

  ## Make sure bar has correct color at its final state 
  if ($percent != 0){
    $bar = "\e[$self->{startRow};$self->{barStart}H\e[K".$self->{fillColor}.($self->{char}x($count))."\e[0m";
    $bar .= "\e[$self->{startRow};${startCol}H".$self->{barColor}.($self->{char}x($self->{scale}-$count))."\e[0m";
  }
  else{
    $bar = "\e[$self->{startRow};${startCol}H".$self->{barColor}.($self->{char}x($self->{scale}-$count))."\e[0m"; 
  }

  $bar .=  $self->_printPercent($percent);
  $bar .=  $self->_printSubText();

  print $FH $bar; 
}


##
## Clear the count of status bar. This is so you can
## use the same object several times and set the
## scale and totalItems differently each run
##
sub reset {
  my ($self, $newDefaults) = @_;

  @$self{qw(count start prevSubText subText 
            subTextChange subTextLength curItems 
            totalItems)} = (0,0,'','',0,0,0,0);

  if ($newDefaults){
    for my $k (keys %$newDefaults){
      ## Just in case
      next if $k eq 'reset';
      $self->$k($newDefaults->{$k});
    }
  }
}


##
## Prints percent to screen
##
sub _printPercent {
  my ($self, $percent) = @_;

  my $t = "\e[$self->{startRow};".($self->{barStart}+$self->{scale}+1)."H";
  $t   .= "\e[37m$percent%       \e[0m";

  return $t;
}


##
## Calculates position to place sub-text
##
sub _printSubText {
  my ($self) = @_;
  my ($pos, $t);

  return if !$self->{subText} || !$self->{subTextChange};

  if ($self->{subTextAlign} eq 'center'){
    my $tmp = int($self->{scale}/2) + $self->{barStart};
    $pos = $tmp - int($self->{subTextLength}/2);
  }
  elsif ($self->{subTextAlign} eq 'right'){
    $pos = $self->{barStart} + $self->{scale} + $self->{startCol} - $self->{subTextLength};
  }
  else{
    $pos = $self->{startCol}+$self->{barStart};
  }

  $t  = "\e[".($self->{startRow}+1).";$self->{startCol}H";
  $t .= ' 'x($self->{barStart}+$self->{scale});
  $t .= "\e[".($self->{startRow}+1).";${pos}H".$self->{subText};

  return $t;
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

Term::StatusBar provides an easy way to create a terminal status bar, 
much like those found in a graphical environment. Term::Size is used to
ensure the bar does not extend beyond the terminal's width. All outout 
is sent to STDOUT by default.

=head1 METHODS

=head2 new(parameters)

This creates a new StatusBar object. It can take several parameters:

   startRow     - This indicates which row to place the bar at. Default is 1.
   startCol     - This indicates which column to place the bar at. Default is 1.
   label        - This places text to the left of the status bar. Default is "Status: ".
   scale        - This indicates how long the bar is. Default is 40.
   totalItems   - This tells the bar how many items are being iterated. Default is 1.
   char         - This indicates which character to use for the base bar. Default is ' ' (space).
   updateInc    - Updates bar every X%. Default is every 1%.
   subText      - Text to display below the status bar.
   subTextAlign - How to align subText ('left', 'center', 'right').
   reverse      - Status bar empties to 0% rather than fills to 100%.
   barColor     - Base color of the status bar (default white -- \e[7;37m).
   fillColor    - Fill color of the status bar (default blue -- \e[7;34m).
   fh           - User-defined file handle.
   precision    - Formats percentage with decimals. Up to 4 places supported.
   showTime     - Shows approximate time to completion in "00:00:00" format.

=head2 setItems(#)

This method does several things with the number that is passed in. First it sets 
$obj->{totalItems}, second it sets an internal counter 'curItems', last it 
determines the update increment.

This method must be used, unless you pass totalItems to the constructor.

=head2 subText('text')

Sets subText and redisplays it if necessary.

=head2 addSubText('text')

This takes the original value of $obj->{subText} and concats 'text' to it 
each time it is called. Text is then re-displayed to screen. 

=head2 start()

This method 'draws' the initial status bar on the screen.

=head2 update()

This is really the core of the module. This updates the status bar and 
gives the appearance of movement. It really just redraws the entire thing, 
adding any new incremental updates needed.

=head2 reset([\%options])

This resets the bar's internal state and makes it available for re-use. If 
the optional hash ref is passed in, the status bar can be filled with 
specified values. The keys are interpreted as function calls on the status 
bar object with the values as parameters.

=head2 _printPercent()

Internal method to print the current percentage to the screen.

=head2 _printSubText()

Internal method to print the subText to the screen.

=head1 CHANGES

   2003-05-06
      Fixed bug where subTextLength was not being re-evaluated.
      Bar's final state color is now appropriate. When emptied to 0% is was getting re-filled.
      Added "no warnings 'portable" so Perl 5.8 would be happy.
      Added ability to send output to user-defined file handle.
      Added precision for percentage output to a max of 4 decimal places. Default is 0.
      Can now specify a different 'updateInc', which adjusts how often the bar is updated. Default is every 1%.
      Can now indicate if you want to see approximate time to completion.  

   2003-01-27
      Added 'reverse' option to constructor.
      Cleaned up code a bit.
      Only update items when needed (subText was being updated even if it had not changed).
      Pre-compute lengths and use static value rather than calling length() every iteration.

=head1 AUTHOR

Shay Harding E<lt>sharding@ccbill.comE<gt>

=head1 COPYRIGHT

This library is free software;
you may redistribute and/or modify it under the same
terms as Perl itself.

=head1 SEE ALSO

L<Term::Size>, L<Term::Report>

=cut

