# frozen_string_literal: true

source 'https://rubygems.org'

group :code_analysis do
  gem 'rubocop', '~> 1.24'
  gem 'rubocop-performance', '~> 1.13'
  gem 'rubocop-rake', '~> 0.6'
  gem 'rubocop-rspec', '~> 2.7'
end

group :development, :test do
  gem 'pry', '~> 0.14'
  gem 'rake', '~> 13.0'
end

group :test do
  gem 'rspec', '~> 3.10'
  gem 'simplecov', '~> 0.21', require: false
  gem 'timecop', '~> 0.9'
end

if RUBY_ENGINE == 'ruby' && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.7.0')
  group :benchmark do
    gem 'activesupport', '~> 7.0'
  end
end

gemspec
