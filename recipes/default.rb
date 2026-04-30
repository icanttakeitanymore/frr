if node['frr']['bgp_groups'].nil? || node['frr']['bgp_groups'].empty?
  raise "Attribute node['frr']['bgp_groups'] is required and must contain at least one group!"
end

node['frr']['bgp_groups'].each do |group_name, group|
  %w(router_id local_as advertised_prefixes neighbors).each do |attr|
    if group[attr].nil?
      raise "Attribute node['frr']['bgp_groups']['#{group_name}']['#{attr}'] is required but not set!"
    end
  end

  unless group['advertised_prefixes'].is_a?(Array)
    raise "node['frr']['bgp_groups']['#{group_name}']['advertised_prefixes'] must be a non-empty Array"
  end

  unless group['neighbors'].is_a?(Array) && !group['neighbors'].empty?
    raise "node['frr']['bgp_groups']['#{group_name}']['neighbors'] must be a non-empty Array"
  end

  # 🔹 receive_prefixes (optional)
  if group['receive_prefixes']
    unless group['receive_prefixes'].is_a?(Array)
      raise "receive_prefixes must be a non-empty Array if set"
    end

    group['receive_prefixes'].each_with_index do |pfx, idx|
      if pfx.nil? || pfx.to_s.empty?
        raise "Each receive_prefix must be non-empty — missing in receive_prefixes[#{idx}]"
      end
    end
  end

  group['neighbors'].each_with_index do |n, idx|
    if n['ip'].nil? || n['ip'].to_s.empty? || n['remote_as'].nil?
      raise "Each neighbor must have ip and remote_as — error in neighbors[#{idx}]"
    end
  end
end

package 'frr'

# ==== CONFIG ====

template '/etc/frr/frr.conf' do
  source 'frr.conf.erb'
  variables(
    hostname: node['fqdn'],
    bgp_groups: node['frr']['bgp_groups']
  )
  verify 'vtysh -C -f /etc/frr/frr.conf'
  notifies :restart, 'service[frr]'
end

template '/etc/frr/daemons' do
  source 'daemons.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables(
    router_ids: node['frr']['bgp_groups'].values.map { |g| g['router_id'] },
    bgpd_port: node['frr']['bgpd_port'] || 179
  )
  action :create
  notifies :restart, 'service[frr]'
end

service 'frr' do
  action [:enable, :start]
end

# 5 tuples ECMP
sysctl 'net.ipv4.fib_multipath_hash_policy' do
  value '1'
  action :apply
end
