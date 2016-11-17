# This assumes that the gitea rpm and dependencies have been cached by the
# pltraining-bootstrap module.
class classroom::master::gitea {
  package { '/usr/src/rpm_cache/gitea.rpm':
    source => '/usr/src/rpm_cache/gitea.rpm',
    before => File['/home/git/go/bin/custom/conf/app.ini'],
  }

  file { '/home/git/go/bin/custom/conf/app.ini':
    ensure => file,
    owner  => 'git',
    group  => 'git',
    mode   => '0644',
    source => 'puppet:///modules/classroom/app.ini.erb',
    notify => Service['gitea'],
  }

  service { 'gitea':
    ensure  => 'running',
  }
}