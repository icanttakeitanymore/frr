resource_name :dummy_operator
provides :dummy_operator

property :ifname, String, name_property: true
property :http_check_url, String, required: true
property :http_check_status_codes, Array, default: [200]
property :http_check_fail, Integer, default: 3
property :http_check_raise, Integer, default: 1
property :http_check_interval, Integer, default: 1000
property :http_check_timeout, Integer, default: 1000

action :create do
  script_path = "/usr/local/bin/dummy_operator.py"
  unit_name = "dummy-operator-#{new_resource.ifname}"

  cookbook_file script_path do
    source 'dummy_operator.py'
    owner 'root'
    group 'root'
    mode '0755'
    notifies :restart, "service[#{unit_name}]", :delayed
  end

  systemd_unit "#{unit_name}.service" do
    content(
      Unit: {
        Description: "Dummy Operator for #{new_resource.ifname}",
        After: "network.target"
      },
      Service: {
        ExecStart: "/usr/bin/python3 #{script_path} " \
                   "--iface #{new_resource.ifname} " \
                   "--url #{new_resource.http_check_url} " \
                   "--ok-codes #{new_resource.http_check_status_codes.join(",")} " \
                   "--fail-threshold #{new_resource.http_check_fail} " \
                   "--raise-threshold #{new_resource.http_check_raise} " \
                   "--interval #{new_resource.http_check_interval} " \
                   "--timeout #{new_resource.http_check_timeout}",
        Restart: "always",
        RestartSec: "1"
      },
      Install: {
        WantedBy: "multi-user.target"
      }
    )
    action [:create, :enable]
    notifies :restart, "service[#{unit_name}]", :delayed
  end

  service unit_name do
    action :nothing
  end
end

action :delete do
  unit_name = "dummy-operator-#{new_resource.ifname}"

  service unit_name do
    action [:stop, :disable]
    ignore_failure true
  end

  systemd_unit "#{unit_name}.service" do
    action [:stop, :disable, :delete]
  end
end