package Foswiki::Contrib::VirtualHostingContrib::VirtualHost;

use File::Basename;
use Cwd;
our $CURRENT = undef;

BEGIN {
  if (!$Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir}) {
    my $path = Cwd::abs_path($Foswiki::cfg{DataDir} . '/../virtualhosts');
    $path =~ /(.*)$/; $path = $1; # untaint, we trust Foswiki configuration

    $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} = $path;
  }
}

sub find {
  my ($class, $hostname) = @_;
  $hostname = _validate_hostname($hostname);
  if (!$hostname) {
    return undef;
  }

  # check whether the given virtual host directory exists or not
  if (!$class->exists($hostname)) {
    return undef;
  }

  my $DataDir         = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . "/$hostname/data";
  my $WorkingDir      = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . "/$hostname/working";
  my $PubDir          = $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . "/$hostname/pub";
  my $self            = {
    hostname => $hostname,
    directory => $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . "/$hostname",
    config => {
      DataDir               => $DataDir,
      PubDir                => $PubDir,
      WorkingDir            => $WorkingDir,
      DefaultUrlHost        => "http://$hostname",
      # values defined in terms of DataDir
      Htpasswd => {
        FileName            => "$DataDir/.htpasswd",
      },
      ConfigurationLogName  => "$DataDir/configurationlog.txt",
      DebugFileName         => "$DataDir/debug%DATE%.txt",
      WarningFileName       => "$DataDir/warn%DATE%.txt",
      LogFileName           => "$DataDir/log%DATE%.txt",
      RCS => {
        WorkAreaDir         => "$WorkingDir/work_areas",
      },
      TempfileDir           => "$WorkingDir/tmp",
    }
  };

  bless $self, $class;

  $self->{config}->{TemplatePath} = $self->_template_path();
  $self->_load_config();

  return $self;
}

sub hostname {
  my $self = shift;
  return $self->{hostname};
}

sub exists {
  my ($class, $hostname) = @_;
  return -d $Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . "/$hostname/data";
}

sub run {
  my ($self, $code) = @_;

  local $Foswiki::Contrib::VirtualHostingContrib::VirtualHost::CURRENT = $self->hostname;

  $self->_run_with_local_configuration($code, %{$self->{config}});
}

# Recursive method; consumes the local configuration, updates Foswiki global
# configuration with local() and runs the code inside the virtualhost.  This
# method needs to be recursive because if the configurations were set in a
# loop, the local() declarations would lose their scope just after the loop.
sub _run_with_local_configuration {
  my ($self, $code, %config) = @_;
  if (scalar(%config)) {
    my @keys = keys(%config);
    my $key = $keys[0];
    local $Foswiki::cfg{$key} = _merge_config($Foswiki::cfg{$key}, $config{$key});
    delete $config{$key};
    $self->_run_with_local_configuration($code, %config);
  } else {
    &$code();
  }
}

sub _merge_config {
  my ($global, $local)= @_;
  if (ref($global) eq 'HASH' || ($local) eq 'HASH') {
    # merge hashes
    my %newhash = %{$global};
    for my $key (keys(%{$local})) {
      $newhash{$key} = _merge_config($global->{$key}, $local->{$key});
    }
    \%newhash;
  } else {
    $local;
  }
}

# StaticMethod
sub run_on_each {
  my ($class, $code) = @_;
  my @hostnames = map { basename $_} glob($Foswiki::cfg{VirtualHostingContrib}{VirtualHostsDir} . '/*');
  @hostnames = grep { $class->exists($_) && $_ ne '_template' } @hostnames;
  for my $hostname (@hostnames) {
    my $virtual_host = $class->find($hostname);
    $virtual_host->run($code);
  }
}

sub _config {
  my ($self, $key) = @_;
  return $self->{config}->{$key} || $Foswiki::cfg{$key};
}

sub _validate_hostname {
  my $hostname = shift;
  return undef unless $hostname;
  if ($hostname =~ /^[\w-]+(\.[\w-]+)*$/) {
    return $&;
  } else {
    return undef;
  }
}

sub _template_path {
  my $self = shift;
  my $template_dir = $self->{directory} . '/templates';
  my @path = ();
  for my $component (split(/\s*,\s*/, $Foswiki::cfg{TemplatePath})) {
    if ($component =~ m/^\$Foswiki::cfg{TemplateDir}\/(.*)/ ||
      $component =~ m/^$Foswiki::cfg{TemplateDir}\/(.*)/) {
      my $relative_path = $1;
      # search in the virtual host templates directory
      push @path, "$template_dir/$relative_path";
    }
    # search in the system-wide templates
    push @path, $component;
  }
  return join(',', @path);
}

sub _load_config {
  my $self = shift;
  my $config_file = $self->{directory} . '/VirtualHost.cfg';
  if (-r $config_file) {
    my %VirtualHost;
    open CONFIG, $config_file;
    my @config = <CONFIG>;
    my $config = join('',@config);

    # untaint; we trust the virtual host configuration file
    $config =~ /(.*)/ms; $config = $1;

    # Replace $Foswiki::cfg with $VirtualHost, so that virtual hosts cannot
    # mess with the global configuration, even if they want to.
    $config =~ s/\$Foswiki::cfg/\$VirtualHost/g;

    eval $config;
    close CONFIG;
    for my $key (keys(%VirtualHost)) {
      $self->{config}->{$key} = $VirtualHost{$key};
    }
  }
}

1;
