# ABOUTME: Configures Elasticsearch connection URL and SSL options for Searchkick.
# ABOUTME: Allows environment variable override for Docker/production environments.

unless Rails.env.test?
  unless ENV["ELASTICSEARCH_URL"]
    if ENV["ES_PASSWORD"].present?
      encoded = URI::DEFAULT_PARSER.escape(ENV["ES_PASSWORD"], /[^A-Za-z0-9\-._~]/)
      host    = ENV.fetch("ES_HOST", "localhost")
      port    = ENV.fetch("ES_PORT", "9200")
      ENV["ELASTICSEARCH_URL"] = "http://elastic:#{encoded}@#{host}:#{port}"
    elsif ENV["ES_HOST"]
      host = ENV["ES_HOST"]
      port = ENV.fetch("ES_PORT", "9200")
      ENV["ELASTICSEARCH_URL"] = "http://#{host}:#{port}"
    else
      ENV["ELASTICSEARCH_URL"] = "http://localhost:9200"
    end
  end

  if ENV["ELASTICSEARCH_URL"].start_with?("https")
    Searchkick.client_options = {
      transport_options: { ssl: { verify: false } }
    }
  end
end
