unless Rails.env.test?
  ENV["ELASTICSEARCH_URL"] = "https://elastic:elastic@localhost:9200"

  Searchkick.client_options = {
  	transport_options: { ssl: { verify: false } },
    ca_fingerprint: "3B:50:55:11:48:84:DA:97:F0:87:6B:AE:B4:6E:16:ED:DC:E8:01:E0:31:E5:00:F0:F9:2F:06:6C:1C:09:C4:03"
  }
end
