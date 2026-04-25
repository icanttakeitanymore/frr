require 'json'
require 'mixlib/shellout'
require 'openssl'

module FRR
  module BGP
    class Summary
      def initialize(vrf: 'default')
        @vrf = vrf
      end

      def fetch_raw
        cmd = Mixlib::ShellOut.new(
          'vtysh -c "show bgp summary json"',
          timeout: 10
        )
        cmd.run_command
        cmd.error!

        cmd.stdout
      end

      def fetch_parsed
        JSON.parse(fetch_raw)
      end

      def neighbors
        data = fetch_parsed

        vrf_data = data.dig('ipv4Unicast')
        return [] unless vrf_data && vrf_data['peers']

        vrf_data['peers'].map do |ip, peer|
          {
            ip: ip,
            local_ip: vrf_data['routerId'],
            state: peer['state'],
            peer_state: peer['peerState'],
            remote_as: peer['remoteAs'],
            local_as: peer['localAs'],
            uptime: peer['peerUptime'],
            prefixes_received: peer['pfxRcd'],
            prefixes_sent: peer['pfxSnt'],
            connections_established: peer['connectionsEstablished'],
            connections_dropped: peer['connectionsDropped'],
          }
        end
      end

      def down_neighbors
        neighbors.reject { |n| n[:state] == 'Established' }
      end

      def up_neighbors
        neighbors.select { |n| n[:state] == 'Established' }
      end

      def metric_labels(neighbor)
        {
          peer: neighbor[:ip],
          remote_as: neighbor[:remote_as].to_s,
          local_as: neighbor[:local_as].to_s,
          local_ip: neighbor[:local_ip],
        }
      end

      def metric_hash(neighbor)
        OpenSSL::Digest::SHA256.hexdigest("#{neighbor[:ip]}-#{neighbor[:remote_as]}-#{neighbor[:local_as]}")
      end
    end
  end
end
