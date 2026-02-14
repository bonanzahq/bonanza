source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.8"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "8.0.4"
gem "minitest", "5.25.4"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails", "3.5.2"

# Use pg as the database for Active Record
gem "pg", "1.6.3"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "6.6.0"

# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem "jsbundling-rails", "1.3.1"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails", "2.0.23"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails", "1.3.4"

# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails", "1.4.3"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder", "2.14.1"

# Use Redis adapter to run Action Cable in production
# gem "redis", "~> 4.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "3.1.21"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", "1.23.0", require: false

# Use Sass to process CSS
# gem "sassc-rails"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

### Bonanza Redux Gems
# Devise
gem "devise", "5.0.1"

# cancancan
gem 'cancancan', "3.6.1"

# pagination
gem "kaminari", "1.2.2"

# fulltext search
gem "pg_search", "2.3.7"

# tags
gem "acts-as-taggable-on", "13.0.0"

# profile pics
gem 'ruby_identicon', "0.0.6"

# faster json
gem 'oj', "3.16.15"

# searchkick for elasticsearch

gem 'searchkick', "6.0.3"
gem 'elasticsearch', "8.19.3"

# markdown parser

gem 'redcarpet', "3.6.1"

### Not for v1

# email check
# gem "valid_email2"

# devise invitable
gem 'devise_invitable', "2.0.11"

####

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]

  gem 'factory_bot_rails', "6.5.1"
  gem 'faker', "3.6.0"
end

group :test do
  gem 'capybara', "3.40.0"
  gem 'selenium-webdriver', "4.40.0"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console", "4.2.1"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"

  gem "awesome_print", "1.9.2"
  gem "seed_dump", "3.4.1"

  # Code quality
  gem "rubocop", "1.84.2", require: false
  gem "rubocop-rails", "2.34.3", require: false
  gem "rubocop-performance", "1.26.1", require: false
end

