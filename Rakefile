# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

desc 'Run Rubocop'
RuboCop::RakeTask.new

desc 'Run all examples'
RSpec::Core::RakeTask.new(:rspec)

task default: %i[rubocop rspec]
