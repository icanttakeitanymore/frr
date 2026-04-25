bgp = FRR::BGP::Summary.new

bgp.neighbors.each do |neighbor|
  node_metric "frr_bgp_session_state" do
    help 'BGP session state'
    value_type 'gauge'
    filename_suffix bgp.metric_hash neighbor
    labels bgp.metric_labels neighbor
    value neighbor[:state] == 'Established' ? 1 : 0
  end

  node_metric "frr_bgp_prefixes_sent" do
    help 'Prefixes advertised to BGP peer'
    value_type 'gauge'
    filename_suffix bgp.metric_hash neighbor
    labels bgp.metric_labels neighbor
    value neighbor[:prefixes_sent]
  end

  node_metric "frr_bgp_prefixes_received" do
    help 'Prefixes received from BGP peer'
    value_type 'gauge'
    filename_suffix bgp.metric_hash neighbor
    labels bgp.metric_labels neighbor
    value neighbor[:prefixes_received]
  end

  node_metric "frr_bgp_connections_established" do
    help 'Number of BGP session establishments'
    value_type 'counter'
    filename_suffix bgp.metric_hash neighbor
    labels bgp.metric_labels neighbor
    value neighbor[:connections_established]
  end

  node_metric "frr_bgp_connections_dropped" do
    help 'Number of BGP session drops'
    value_type 'counter'
    filename_suffix bgp.metric_hash neighbor
    labels bgp.metric_labels neighbor
    value neighbor[:connections_dropped]
  end
end
