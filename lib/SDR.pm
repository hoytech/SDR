package SDR;

use common::sense;

our $VERSION = '0.100';

use Symbol;



our $known_radio_capabilities = {
  tx => [qw{ HackRF }],
  rx => [qw{ HackRF RTLSDR }],
};


sub radio {
  my ($class, %args) = @_;

  my $can = $args{can} || 'rx'; ## FIXME: support requesting multiple capabilities as an array ref

  my $possible_radios = $known_radio_capabilities->{$can};

  my @errors;
  my $radio;

  foreach my $radio_name (@$possible_radios) {
    my $module = "SDR::Radio::$radio_name";

    eval "require $module";
    if ($@) {
      push @errors, "$module -- not installed";
      next;
    }

    $radio = eval {
      no strict "refs";
      return qualify("new", $module)->($module, %{ $args{args} });
    };

    if ($@) {
      push @errors, "$module -- $@";
      next;
    }

    last;
  }

  return $radio if $radio;

  die "Unable to find any suitable radio:\n\n" . join("\n", @errors) . "\nPlease install one of the above modules.\n";
}



sub audio_sink {
  my ($class, %args) = @_;

  my $audio_sink;
  my @errors;

  my $sample_rate = $args{sample_rate};
  die "need sample_rate" if !defined $sample_rate;

  my $format = $args{format};
  die "unsupported format: $format" if $format ne 'float'; ## FIXME

  eval {
    open($audio_sink,
         '|-:raw',
         qw{ pacat --stream-name fmrecv --format float32le --channels 1 --latency-msec 10 },
                   '--rate' => $sample_rate,
        ) || die "failed to run pacat: $!";
  };

  if ($@) {
    push @errors, "pulse audio: $@";
  } else {
    return $audio_sink;
  }

  eval {
    open($audio_sink,
         '|-:raw',
         qw{ play -t raw -e float -b 32 -c 1 -q },
         '-r' => $sample_rate,
         '-',
        ) || die "failed to run play: $!";
  };

  if ($@) {
    push @errors, "SoX: $@";
  } else {
    return $audio_sink;
  }

  die "Unable to run any suitable audio sink:\n\n" . join("\n", @errors);
}


1;



__END__


=encoding utf-8

=head1 NAME

SDR - Software-Defined Radio

=head1 SYNOPSIS

    use SDR;

    my $radio = SDR->radio(can => 'rf');

    $radio->frequency(104_500_000);
    $radio->sample_rate(2_000_000);

    $radio->rx(sub {
      ## process IQ samples in $_[0]
    });

    $radio->run;
