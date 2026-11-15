package Ads::Template;

#
# This is the HTML templates parsing module
#
#

my $delimiter      = chr(27); # delimit blocks, tags, and html's - 27
my $tag_sign       = chr(15); # tag sign
my $begin_block    = chr(16); # begin block sign - 16
my $end_block      = chr(17); # end block sign - 17

sub new {
  my $self                = {};
  $self->{globals}        = {};  # initial data: files and blocks
  $self->{blocks}         = {};  # resulted data and variables
  $self->{block_keys}     = {};   # associate array (short key, full key)
  $self->{parse_array}    = [];  # array ready for parsing
  $self->{block_path}     = "";
  $self->{position}       = 0;   # position in parse string
  $self->{length}         = 0;   # length of parse string 
  return bless $self;
}

sub LoadTemplate {
  my ($self, $filename, $block_name, $options) = @_;

  my $file_path = $filename;  

  if (-e $file_path) {

    # load template file
    open(template_file, $file_path );
    my $file_content;
    {
      local $/=undef;
      $file_content = <template_file>;
    }
    close(template_file);

    # preparing file content for parsing
    $file_content =~ s/<!\-\-\s*begin_\s*([\w\s]*\w+)\s*\-\->/$delimiter . $begin_block . $delimiter . $1 . $delimiter/gise;
    $file_content =~ s/<!\-\-\s*end_\s*([\w\s]*\w+)\s*\-\->/$delimiter . $end_block . $delimiter . $1 . $delimiter/gise;
    $file_content =~ s/\{(\w+)\}/$delimiter . $tag_sign . $delimiter . $1 . $delimiter/gise;

    @{$self->{parse_array}} = split /$delimiter/, $file_content;

    $self->{position} = 0;
    $self->{length}   = $#{$self->{parse_array}} + 1;

    my @block_names;
    $block_names[0] = $block_name;

    $self->set_block(\@block_names, "false");

	$self->setvar("HTTP_ROOT", $options->{HTTP_ROOT})
  }
}

sub UnloadTemplate {
  my ($self, $block_name) = @_;
  for my $key (keys %{$self->{blocks}}) {
    if ($key =~ m/^\/$block_name/ ) {
      delete($self->{blocks}{$key})
    }
  }
}

sub set_block {
  my ($self, $block_names, $is_subblock) = @_;

  if ( $is_subblock eq "true" or $is_subblock eq "" ) {
    $is_subblock = 1 
  } else { 
    $is_subblock = 0
  }

  my $block_level = $#{$block_names} + 1;

  my $block_name = "/" . join("/", @{$block_names});

  my $block_number = 0; 
  my @block_array;
  $block_array[0] = 0;

  while ($self->{position} < $self->{length}) {

    my $element_array = $self->{parse_array}->[$self->{position}];

    if ( $element_array eq $tag_sign ) {

        $block_number++;
        $block_array[$block_number] = $self->{parse_array}->[$self->{position} + 1];
        $self->{position} += 2;
    
    } elsif ($element_array eq $begin_block) {

        $block_number++;
        $block_array[$block_number] = $block_name . "/" . $self->{parse_array}->[$self->{position} + 1];
        $self->{position} += 2;
        $block_names->[$block_level] = $self->{parse_array}->[$self->{position} - 1];

        my @tmp_arr_ref = @{$block_names};
        $self->set_block(\@tmp_arr_ref, "true");

    } elsif ( ($element_array eq $end_block) && $is_subblock) {

       if ( $self->{parse_array}->[$self->{position} + 1] eq $block_names->[$block_level - 1] ) {

          $block_array[0] = $block_number;
          $self->{position} += 2;
          $self->{blocks}->{$block_name} = \@block_array;
          my @tmp_arr_ref = @{$block_names};
          $self->set_keys(\@tmp_arr_ref);
          return;

        } else {
          die "Error in block: $block_name";
        } 
    } else {
        $block_number++;
        $block_array[$block_number] = $block_name . "#" . $block_number;
        $self->{globals}->{$block_name . "#" . $block_number} = $element_array;
        $self->{position}++;
    }
    $block_array[0] = $block_number;
    $self->{blocks}->{$block_name} = \@block_array;
    my @tmp_arr_ref = @{$block_names};
    $self->set_keys(\@tmp_arr_ref);
  }
}

sub set_keys {
  my ($self, $block_names) = @_;
  my $full_block_name = "/" . join("/", @{$block_names});
  my $key = "";
  for(my $i = $#{$block_names}; $i >= 0; $i--) {
    $key = "/" . $block_names->[$i] . $key;
    if(!$self->{block_keys}{$key}) {
      $self->{block_keys}{$key} = $full_block_name;
    }
  }
}

sub blockexists {
  my ($self, $block_name) = @_;
  $block_name = $self->getname($block_name, "true");
  return $self->{blocks}->{$block_name};
}

sub setvar {
  my ($self, $key, $value) = @_;
#  $value = $value;
  $self->{globals}->{$key} = $value;
}

sub setblockvar {
  my ($self, $key, $value) = @_;
#  $value = $$value;
  $key = $self->getname($key, "true");
  $self->{globals}->{$key} = $value;
}

sub replaceblock {
  my ($self, $key, $value) = @_;
#  $value = $$value;
  $key = $self->getname($key, "true");
  $self->{globals}->{$key} = $value;
  $self->{blocks}->{$key}  = "";
}

sub getvar {
  my ($self, $key) = @_;
  $key = $self->getname($key, "false");
  return $self->{globals}->{$key};
}

sub parse {
  my ($self, $block_name, $accumulate) = @_;
  $accumulate ||= "true";
  $self->globalparse($block_name, $accumulate, "");
}

sub parsesafe {
  my ($self, $block_name, $accumulate) = @_;
  $accumulate ||= "true";
  if ($self->blockexists($block_name)) {
    $self->globalparse($block_name, $accumulate, "");
  }
}

sub rparse {
  my ($self, $block_name, $accumulate) = @_;
  $accumulate ||= "true";
  $self->globalparse($block_name, $accumulate, "", "false", "true");
}

sub parseto {
  my ($self, $block_name, $accumulate, $parse_to) = @_;
  $self->globalparse($block_name, $accumulate, $parse_to);
}

sub globalparse {
  my ($self, $block_name, $accumulate, $parse_to, $output, $reverse) = @_;

  $accumulate ||= "true";
  $output     ||= "false"; 
  $reverse    ||= "false";

  if ( $accumulate eq "true" or $accumulate eq "" ) {
    $accumulate = 1 
  } else {
    $accumulate = 0
  }

  if ($output eq "true") {
    $output = 1 
  } else {    
    $output = 0
  } 

  $block_name = $self->getname($block_name, "true");

  if ($parse_to eq "") { 
    $parse_to = $block_name 
  } else { 
    $parse_to = $self->getname($parse_to, "true")
  }

  my @block_array = defined $self->{blocks}->{$block_name} ? @{$self->{blocks}->{$block_name}} : ();

  if ( $#block_array > -1 ) {
    my %globals;
    %globals = %{$self->{globals}};

    my $array_size = $block_array[0];

    my $block_value = "";
  
    for(my $i = 1; $i <= $array_size; $i++) {
      $block_value .= exists($globals{$block_array[$i]}) ? $globals{$block_array[$i]} : "";
    }
    my $left_value = $reverse eq "true" ? $block_value : "";
    my $right_value = $reverse eq "true" ? "" : $block_value;
    $self->{globals}{$parse_to} = ($accumulate && $self->{globals}{$parse_to}) ? $left_value . $self->{globals}{$parse_to} . $right_value : $block_value;
  }
  print $self->{globals}->{$block_name} if ( $output );
}

sub getname {
  my ($self, $array_key, $is_block) = @_;
  
  if ( $is_block eq "true" ) { 
    $is_block = 1 
  } else { 
    $is_block = 0
  }

  if ( defined($array_key) && length($array_key) && substr($array_key, 0, 1) ne "/") {
     $array_key = "/" . $array_key;
  }

  my %searching_array;
  if ($is_block) {
    %searching_array = %{$self->{blocks}};
  } else {
    %searching_array = %{$self->{globals}};
  }

  if ( length($self->{block_path} )) {

    if (substr($self->{block_path}, 0, 1) ne "/") {
       $self->{block_path} = "/" . $self->{block_path};
    }

    if ( substr($self->{block_path}, length($self->{block_path}) - 1, 1) eq "/") {
      $self->{block_path} = substr($self->{block_path}, 1, length($self->{block_path}) - 1);
    }
    if ( defined($array_key) && length($array_key) ) {
      $array_key = $self->{block_path} . $array_key;
    } else {
      $array_key = $self->{block_path};
    }
  }

  if ( $is_block && $self->{block_keys}{$array_key} ) {
    $array_key = $self->{block_keys}{$array_key};
  } elsif (!$searching_array{$array_key}) {
    while ( my ($key,$value) = each(%searching_array)) {
      my $key_len = length($key);
      my $array_key_len = length($array_key);
      if ($key_len >= $array_key_len && (substr($key, $key_len - $array_key_len, $array_key_len) eq $array_key) ) {
        $array_key = $key;
        last;
      }
    }
  }
  return $array_key;
}

sub pparse {
  my ($self, $block_name, $accumulate) = @_;
  $accumulate ||= "true";
  $self->globalparse($block_name, $accumulate, "", "true");
}

1;

