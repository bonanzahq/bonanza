# ABOUTME: Configures Elasticsearch connection URL and SSL options for Searchkick.
# ABOUTME: Allows environment variable override for Docker/production environments.

unless Rails.env.test?
  ENV["ELASTICSEARCH_URL"] ||= "https://elastic:elastic@localhost:9200"

  if ENV["ELASTICSEARCH_URL"].start_with?("https")
    Searchkick.client_options = {
      transport_options: { ssl: { verify: false } }
    }
  end
end
