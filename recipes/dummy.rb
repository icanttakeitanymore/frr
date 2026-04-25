file '/etc/modules-load.d/dummy.conf' do
  content "dummy\n"
  owner 'root'
  group 'root'
  mode '0644'
end

execute 'modprobe dummy' do
  command 'modprobe dummy'
  not_if 'lsmod | grep -q "^dummy"'
end

node['frr']['dummies']['ifaces'].each do |ifname, conf|
  file "/etc/network/interfaces.d/#{ifname}" do
    content <<~EOF
      auto #{ifname}
      iface #{ifname} inet static
          address #{conf[:address]}

          pre-up ip link add #{ifname} type dummy || true
    EOF
    owner 'root'
    group 'root'
    mode '0644'
    notifies :reload, 'service[networking]'
    action node['frr']['dummies']['ifaces_actions'][ifname]
  end

  dummy_operator ifname do
    http_check_url conf[:url]
    http_check_status_codes conf[:status_codes]
    http_check_status_codes conf[:status_codes]
    http_check_fail conf[:fail] || 3
    http_check_raise conf[:raise] || 1 
    http_check_interval conf[:interval] || 1000
    http_check_timeout conf[:interval] || 1000
    action node['frr']['dummies']['ifaces_actions'][ifname]
  end
end

service 'networking' do
  action :nothing
end
