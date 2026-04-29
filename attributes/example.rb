=begin
Example structure for node['frr']['bgp_groups']:
{
    'primary' => {
        'router_id' => '1.2.3.4',
        'local_as' => 65000,
        'advertised_prefixes' => [
            '1.2.0.0/16 le 24'
        ],
        'receive_prefixes' => [
            '7.4.5.0/24 le 32'
        ],
        'neighbors' => [
            { 'ip' => '1.2.3.5', 'remote_as' => 65001 }
        ],
        'bfd' => true,
        'timers' => '500 3'
    }
}
default['frr']['dummies'] = {
  'ifaces' => {
    'dummy0' => {
      address: '10.100.0.100/32',
      url: "https://#{node[:fqdn]}:443/v1/sys/health",
      status_codes: [200, 429],
      fail: 3,
      raise: 1,
      interval: 1000,
      timeout: 1000
    }
  },

  'ifaces_actions' => {
    'dummy0' => :create
  }
}
=end

default['frr']['bgp_groups'] = nil
