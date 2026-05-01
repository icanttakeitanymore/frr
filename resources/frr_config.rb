provides :frr_config
resource_name :frr_config

property :hostname, String, name_property: true
property :bgp_groups, Hash, required: true
property :path, String, default: '/etc/frr/frr.conf'
property :cookbook, String, default: 'frr'

default_action :create

action_class do
  def validate_bgp_groups!(groups)
    unless groups.is_a?(Hash) && !groups.empty?
      raise Chef::Exceptions::ValidationFailed,
        "bgp_groups must be a non-empty Hash"
    end

    groups.each do |group_name, g|
      ctx = "bgp_groups['#{group_name}']"

      # === REQUIRED FIELDS ===
      %w(router_id local_as neighbors advertised_prefixes).each do |k|
        raise Chef::Exceptions::ValidationFailed, "#{ctx}['#{k}'] is required" if g[k].nil?
      end

      # === TYPE CHECKS ===
      raise Chef::Exceptions::ValidationFailed, "#{ctx}['router_id'] must be String" unless g['router_id'].is_a?(String)
      raise Chef::Exceptions::ValidationFailed, "#{ctx}['local_as'] must be Integer" unless g['local_as'].is_a?(Integer)

      # === PREFIX ARRAYS ===
      validate_prefix_array!(g['advertised_prefixes'], "#{ctx}['advertised_prefixes']")
      validate_prefix_array!(g['receive_prefixes'], "#{ctx}['receive_prefixes']") if g.key?('receive_prefixes')

      # === NEIGHBORS ===
      unless g['neighbors'].is_a?(Array) && !g['neighbors'].empty?
        raise Chef::Exceptions::ValidationFailed,
          "#{ctx}['neighbors'] must be a non-empty Array"
      end

      g['neighbors'].each_with_index do |n, i|
        nctx = "#{ctx}['neighbors'][#{i}]"

        unless n.is_a?(Hash)
          raise Chef::Exceptions::ValidationFailed, "#{nctx} must be a Hash"
        end

        %w(ip remote_as).each do |k|
          raise Chef::Exceptions::ValidationFailed,
            "#{nctx}['#{k}'] is required" if n[k].nil?
        end

        raise Chef::Exceptions::ValidationFailed, "#{nctx}['ip'] must be String" unless n['ip'].is_a?(String)
        raise Chef::Exceptions::ValidationFailed, "#{nctx}['remote_as'] must be Integer" unless n['remote_as'].is_a?(Integer)

        if n['port'] && !n['port'].is_a?(Integer)
          raise Chef::Exceptions::ValidationFailed, "#{nctx}['port'] must be Integer"
        end

        if n['timers'] && !n['timers'].is_a?(String)
          raise Chef::Exceptions::ValidationFailed, "#{nctx}['timers'] must be String (e.g. '300 3')"
        end

        %w(bfd next_hop_self is_rr_client).each do |flag|
          if n.key?(flag) && !!n[flag] != n[flag]
            raise Chef::Exceptions::ValidationFailed,
              "#{nctx}['#{flag}'] must be boolean"
          end
        end
      end

      # === OPTIONAL GROUP FLAGS ===
      if g['multipath'] && !!g['multipath'] != g['multipath']
        raise Chef::Exceptions::ValidationFailed,
          "#{ctx}['multipath'] must be boolean"
      end

      if g['bfd'] && !!g['bfd'] != g['bfd']
        raise Chef::Exceptions::ValidationFailed,
          "#{ctx}['bfd'] must be boolean"
      end

      if g['timers'] && !g['timers'].is_a?(String)
        raise Chef::Exceptions::ValidationFailed,
          "#{ctx}['timers'] must be String"
      end
    end
  end

  def validate_prefix_array!(arr, ctx)
    if arr.nil?
      raise Chef::Exceptions::ValidationFailed, "#{ctx} must not be nil (use [] if empty)"
    end

    unless arr.is_a?(Array)
      raise Chef::Exceptions::ValidationFailed, "#{ctx} must be an Array"
    end

    arr.each_with_index do |p, i|
      unless p.is_a?(String) && !p.strip.empty?
        raise Chef::Exceptions::ValidationFailed,
          "#{ctx}[#{i}] must be a non-empty String"
      end

      # пока просто базовая проверка, потом можно усилить
      unless p.match?(%r{\A\S+\z})
        raise Chef::Exceptions::ValidationFailed,
          "#{ctx}[#{i}] invalid format '#{p}'"
      end
    end
  end
end

action :create do
  tmp_path = "#{new_resource.path}.chef.tmp"

  template tmp_path do
    source 'frr.conf.erb'
    cookbook new_resource.cookbook

    variables(
      hostname: new_resource.hostname,
      bgp_groups: new_resource.bgp_groups
    )

    sensitive false
    notifies :run, 'execute[validate frr config]'
  end

  execute 'validate frr config' do
    command "vtysh -C -f #{tmp_path}"
    action :nothing
    notifies :run, 'execute[install frr config]'
  end

  execute 'install frr config' do
    command "cp #{tmp_path} #{new_resource.path}"
    action :nothing
    only_if "cmp -s #{tmp_path} #{new_resource.path} || test ! -f #{new_resource.path}"
  end
end