class oracle::server {

  Exec {
    logoutput => true,
  }

  exec {
    "/usr/bin/yum -y update":
      alias => "yumUpdate",
      timeout => 5000;
  }


  package {
    "ntp":
      ensure => installed;
    "htop":
      ensure => installed;
    #"procps":
    #  ensure => installed;
    "unzip":
      ensure => installed;
    "monit":
      ensure => installed;
    "rsyslog":
      ensure => installed;
    "curl":
      ensure => installed;
    "libaio":
      ensure => installed;
    "unixODBC":
      ensure => installed;
    "git":
      ensure => installed;
    "bc":
      ensure => installed;
  }

  service {
    "ntp":
      ensure => stopped;
    "monit":
      require => Package['monit'],
      ensure => running;
    "rsyslog":
      ensure => running;
    #"procps":
    #  require => Package['procps'],
    #  ensure => running,
    #  enable => true;
  }

  file {
    "/etc/sysctl.d":
      ensure => directory;
    "/etc/sysctl.d/60-oracle.conf":
      source => "puppet:///modules/oracle/xe-sysctl.conf";
    "/etc/profile.d/oracle.sh":
      source => "puppet:///modules/oracle/oracle.sh";
  }

  group {
    "sys":
      ensure => present;
    "adm":
      ensure => present;
  }

  user { "syslog":
      ensure => present,
      groups => ["sys","adm"],
  }

}

class oracle::xe {
  file {
    "/tmp/oracle-xe-11.2.0-1.0.x86_64.rpm.zip":
      source => "puppet:///modules/oracle/oracle-xe-11.2.0-1.0.x86_64.rpm.zip";
    "/tmp/xe.rsp":
      source => "puppet:///modules/oracle/xe.rsp";
    "/etc/init.d/oracle-shm":
      mode => 0755,
      source => "puppet:///modules/oracle/oracle-shm";
    "/bin/awk":
      ensure => link,
      target => "/usr/bin/awk";
    "/var/lock/subsys":
      ensure => directory;
  }

  Exec {
    logoutput => true,
  }

  exec {
    #"swapOff":
    #  alias => "swapOff",
    #  command => "/sbin/swapoff -v /dev/VolGroup/lv_swap",
    #  user => root;

    "createSwap":
      alias => "createSwap",
      command => "/bin/dd if=/dev/zero bs=1M count=2048 of=/mnt/swapfile",
      #require => Exec["swapOff"],
      user => root;

    "swapOn":
      alias => "swapOn",
      command => "/sbin/mkswap /mnt/swapfile",
      require => Exec["createSwap"],
      user => root;

    "extraSwap":
      alias => "extraSwap",
      command => "/sbin/swapon -v /mnt/swapfile",
      require => Exec["swapOn"],
      #[Exec["swapOff"],Exec["increaseSwap"],Exec["swapOn"]],
      user => root;

    "unzip xe":
      alias => "unzip xe",
      command => "/usr/bin/unzip -o /tmp/oracle-xe-11.2.0-1.0.x86_64.rpm.zip",
      require => [Package["unzip"],File["/tmp/oracle-xe-11.2.0-1.0.x86_64.rpm.zip"]],
      cwd => "/tmp",
      user => root,
      creates => "/tmp/oracle-xe-11.2.0-1.0.x86_64.rpm";
    #"alien xe":
    #  command => "/usr/bin/alien --to-deb --scripts /tmp/Disk1/oracle-xe-11.2.0-1.0.x86_64.rpm",
    #  cwd => "/tmp/Disk1",
    #  require => Exec["unzip xe"],
    #  creates => "/tmp/Disk1/oracle-xe_11.2.0-2_amd64.deb",
    #  user => root;
    "configure xe":
      command => "/etc/init.d/oracle-xe configure responseFile=/tmp/xe.rsp >> /tmp/xe-install.log",
      require => [Package["oracle-xe"],Exec["update-rc oracle-shm"]],
      user => root;
    "update-rc oracle-shm":
      command => "/sbin/chkconfig oracle-shm on",
      cwd => "/etc/init.d",
      require => File["/etc/init.d/oracle-shm"],
      user => root;
    "oracle-shm":
      command => "/etc/init.d/oracle-shm start",
      user => root,
      require => File["/etc/init.d/oracle-shm"];
  }

  package {
    "oracle-xe":
      provider => "rpm",
      ensure => latest,
      require => [Exec[extraSwap],Exec["unzip xe"],Package["libaio"]],
      source => "/tmp/Disk1/oracle-xe-11.2.0-1.0.x86_64.rpm";
  }
}
