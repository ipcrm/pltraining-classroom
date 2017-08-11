class classroom::master::showoff (
  Optional[String] $course   = undef,
  Optional[String] $event_id = undef,
  Optional[String] $event_pw = undef,
  Optional[String] $variant  = undef,
  Optional[String] $version  = undef,
) inherits classroom::params {
  include stunnel
  require showoff
  require classroom::master::dependencies::rubygems

  if $::classroom_vm_release and versioncmp($::classroom_vm_release, '7.0') >= 0 {
    unless defined('$course')    { fail('The $course is required on VM versions 7.0 and greater.') }
    unless defined('$event_id')  { fail('The $event_id is required on VM versions 7.0 and greater.') }

    $presfile   = "${pick($variant, 'showoff')}.json"
    $password   = pick($event_pw, regsubst($event_id, '^(\w*-)?(\w*)$', '\2'))
    $revision   = pick($version, $latest_courseware[$course])
    $pathname   = regsubst($course, '^(Virtual)(\w+)$', '\2').downcase
    $courseware = "${showoff::root}/courseware/${pathname}"
    $metadata = {
      'email'    => pick($trusted.dig('extensions', 'pp_created_by'), $clientcert),
      'course'   => $course,
      'version'  => $revision,
      'event_id' => $event_id,
      'event_pw' => $password,
    }

    vcsrepo { "${showoff::root}/courseware":
      ensure   => present,
      revision => "${course}-v${revision}",
      provider => git,
      before   => Hash_file['courseware metadata'],
      notify   => Exec['build_pdfs'],
    }

    file { ["${courseware}/stats", "${courseware}/static", "${courseware}/_files/share"]:
      ensure   => directory,
      owner    => $showoff::user,
      group    => 'root',
      mode     => '0644',
      before   => Hash_file['courseware metadata'],
      notify   => Exec['build_pdfs'],
    }

    hash_file { 'courseware metadata':
      path     => "${courseware}/stats/metadata.json",
      value    => $metadata,
      provider => 'json',
      before   => File['courseware metadata'],
      notify   => Exec['build_pdfs'],
    }

    file { 'courseware metadata':
      path     => "${courseware}/stats/metadata.json",
      owner    => $showoff::user,
      group    => 'root',
      mode     => '0644',
      notify   => Exec['build_pdfs'],
    }

    augeas { "courseware protection":
      lens    => "Json.lns",
      incl    => "${courseware}/${presfile}",
      changes => [
        "set dict/entry[.= 'key'] key",
        "set dict/entry[.= 'key']/string ${password}",
        "set dict/entry[.= 'event_id'] event_id",
        "set dict/entry[.= 'event_id']/string ${event_id}",
        "set dict/entry[.= 'event_pw'] event_pw",
        "set dict/entry[.= 'event_pw']/string ${password}",
        "set dict/entry[.= 'courseware_release'] courseware_release",
        "set dict/entry[.= 'courseware_release']/string v${version}",
      ],
    }

    package { 'puppet-courseware-manager':
      ensure   => present,
      provider => gem,
    }

    exec { 'build_pdfs':
      command     => "courseware watermark --output _files/share --no-cache --file ${presfile}",
      cwd         => $courseware,
      path        => '/bin:/usr/bin:/usr/local/bin',
      user        => $showoff::user,
      environment => ['HOME=/tmp'],
      refreshonly => true,
      require     => Package['puppet-courseware-manager'],
    }

    showoff::presentation { 'courseware':
      path      => $courseware,
      file      => $presfile,
      subscribe => Exec['build_pdfs'],
    }

  }
  else {
    if defined('$variant')  { notify { '$variant is not supported on VM < 7.0': }  }
    if defined('$version')  { notify { '$version is not supported on VM < 7.0': }  }
    if defined('$event_id') { notify { '$event_id is not supported on VM < 7.0': } }

    include classroom::master::showoff::legacy
  }


  file { '/etc/stunnel/showoff.pem':
    ensure => 'file',
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
    source => 'puppet:///modules/classroom/showoff.pem',
    before => Stunnel::Tun['showoff-ssl'],
  }

  stunnel::tun { 'showoff-ssl':
    accept  => '9091',
    connect => '127.0.0.1:9090',
    options => 'NO_SSLv2',
    cert    => '/etc/stunnel/showoff.pem',
    client  => false,
  }

  if $classroom::manage_selinux {
    # Source code in stunnel-showoff.te
    file { '/usr/share/selinux/targeted/stunnel-showoff.pp':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => 'puppet:///modules/classroom/selinux/stunnel-showoff.pp',
    }

    selmodule { 'stunnel-showoff':
      ensure => present,
    }
  }

}
