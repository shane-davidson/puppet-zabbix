# == Define: zabbix::startup
#
#  This manage the zabbix related service startup script.
#
# === Requirements
#
# === Parameters
#
# === Example
#
#  zabbix::startup { 'agent':
#  }
#
define zabbix::startup (
  Optional[Stdlib::Absolutepath] $pidfile                = undef,
  Optional[Stdlib::Absolutepath] $agent_configfile_path  = undef,
  Optional[Stdlib::Absolutepath] $server_configfile_path = undef,
  Optional[Zabbix::Databases] $database_type             = undef,
  Optional[String] $zabbix_user                          = undef,
  Optional[String] $binary_name                          = undef,
  String $additional_service_params                      = '',
  String $service_type                                   = 'simple',
  Optional[Boolean] $manage_database                     = undef,
  Optional[String] $service_name                         = $name,
) {
  case $title {
    /agent/: {
      assert_type(Stdlib::Absolutepath, $agent_configfile_path)
    }
    /server/: {
      assert_type(Stdlib::Absolutepath, $server_configfile_path)
      assert_type(Zabbix::Databases, $database_type)
      assert_type(Boolean, $manage_database)
    }
    default: {
      fail('we currently only support a title that contains agent or server')
    }
  }
  # provided by camp2camp/systemd
  if $facts['systemd'] {
    contain systemd
    systemd::unit_file { "${name}.service":
      content => template("zabbix/${service_name}-systemd.init.erb"),
    }
    file { "/etc/init.d/${name}":
      ensure  => absent,
    }
  } elsif $facts['os']['family'] in ['Debian', 'RedHat'] {
    # Currently other osfamily without systemd is not supported
    $osfamily_downcase = downcase($facts['os']['family'])
    file { "/etc/init.d/${name}":
      ensure  => file,
      mode    => '0755',
      content => template("zabbix/${name}-${osfamily_downcase}.init.erb"),
    }
  } elsif $facts['os']['family'] in ['AIX'] {
    file { "/etc/rc.d/init.d/${service_name}":
      ensure  => file,
      mode    => '0755',
      content => epp('zabbix/zabbix-agent-aix.init.epp', { 'pidfile' => $pidfile, 'agent_configfile_path' => $agent_configfile_path, 'zabbix_user' => $zabbix_user }),
    }
    file { "/etc/rc.d/rc2.d/S999${service_name}":
      ensure => 'link',
      target => "/etc/rc.d/init.d/${service_name}",
    }
  } elsif ($facts['os']['family'] == 'windows') {
    exec { "install_agent_${name}":
      command  => "& 'C:\\Program Files\\Zabbix Agent\\zabbix_agentd.exe' --config ${agent_configfile_path} --install",
      onlyif   => "if (Get-WmiObject -Class Win32_Service -Filter \"Name='${name}'\"){exit 1}",
      provider => powershell,
      notify   => Service[$name],
    }
  } else {
    fail('We currently only support Debian, Redhat, AIX and Windows osfamily as non-systemd')
  }
}
