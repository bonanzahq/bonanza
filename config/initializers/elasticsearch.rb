# ABOUTME: Configures Elasticsearch connection URL and SSL options for Searchkick.
# ABOUTME: Constructs connection from ES_HOST/ES_PORT/ES_PASSWORD env vars.

unless Rails.env.test?
  unless ENV["ELASTICSEARCH_URL"]
    host = ENV.fetch("ES_HOST", "localhost")
    port = ENV.fetch("ES_PORT", "9200")
    ENV["ELASTICSEARCH_URL"] = "http://#{host}:#{port}"
  end

  url = ENV["ELASTICSEARCH_URL"]
  client_options = {}

  if url.start_with?("https")
    client_options[:transport_options] = { ssl: { verify: false } }
  end

  # Pass credentials separately to avoid double-encoding by elastic-transport.
  # elastic-transport's __full_url applies CGI.escape to user/password extracted
  # from the URL, but URI.parse returns them still percent-encoded, causing
  # double-encoding (%40 -> %2540). Passing user/password as explicit options
  # avoids the URL parsing path entirely.
  if ENV["ES_PASSWORD"].present?
    client_options[:user] = "elastic"
    client_options[:password] = ENV["ES_PASSWORD"]
  end

  Searchkick.client_options = client_options
end
