# == Class: foreman_proxy_content::dispatch_router
#
# Install and configure Qpid Dispatch Router
#
class foreman_proxy_content::dispatch_router (
) {

  class { '::qpid::router': }

  # SSL Certificate Configuration
  class { '::certs::qpid_router':
    require => Class['qpid::router::install'],
  } ~>
  qpid::router::ssl_profile { 'client':
    ca   => $certs::ca_cert,
    cert => $certs::qpid_router::client_cert,
    key  => $certs::qpid_router::client_key,
  } ~>
  qpid::router::ssl_profile { 'server':
    ca   => $certs::ca_cert,
    cert => $certs::qpid_router::server_cert,
    key  => $certs::qpid_router::server_key,
  }

  # Listen for katello-agent clients
  qpid::router::listener { 'clients':
    addr        => $foreman_proxy_content::qpid_router_agent_addr,
    port        => $foreman_proxy_content::qpid_router_agent_port,
    ssl_profile => 'server',
  }

  # Enable logging for dispatch router
  file { $foreman_proxy_content::qpid_router_logging_path:
    ensure => directory,
    owner  => 'qdrouterd',
  } ~>
  qpid::router::log { 'logging':
    level  => $foreman_proxy_content::qpid_router_logging_level,
    output => "${foreman_proxy_content::qpid_router_logging_path}/qdrouterd.log",
  }

  # Act as hub if pulp master, otherwise connect to hub
  if $foreman_proxy_content::pulp_master {
    qpid::router::listener {'hub':
      addr        => $foreman_proxy_content::qpid_router_hub_addr,
      port        => $foreman_proxy_content::qpid_router_hub_port,
      role        => 'inter-router',
      ssl_profile => 'server',
    }

    # Connect dispatch router to the local qpid
    qpid::router::connector { 'broker':
      addr         => $foreman_proxy_content::qpid_router_broker_addr,
      port         => $foreman_proxy_content::qpid_router_broker_port,
      ssl_profile  => 'client',
      role         => 'on-demand',
      idle_timeout => 0,
    }

    qpid::router::link_route_pattern { 'broker-pulp-route':
      prefix    => 'pulp.',
      direction => 'out',
      connector => 'broker',
    }

    qpid::router::link_route_pattern { 'broker-pulp-task-route':
      prefix    => 'pulp.task',
      direction => 'in',
      connector => 'broker',
    }

    qpid::router::link_route_pattern { 'broker-qmf-route':
      prefix    => 'qmf.',
      connector => 'broker',
    }
  } else {
    qpid::router::connector { 'hub':
      addr         => $foreman_proxy_content::parent_fqdn,
      port         => $foreman_proxy_content::qpid_router_hub_port,
      ssl_profile  => 'client',
      role         => 'inter-router',
      idle_timeout => 0,
    }

    qpid::router::link_route_pattern { 'hub-pulp-route':
      prefix    => 'pulp.',
    }

    qpid::router::link_route_pattern { 'hub-qmf-route':
      prefix    => 'qmf.',
    }
  }
}
