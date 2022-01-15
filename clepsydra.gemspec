# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

require 'clepsydra/version'

Gem::Specification.new do |spec|
  spec.name = 'clepsydra'
  spec.version = Clepsydra::Version::VALUE
  spec.authors = ['Abhimanyu Singh']
  spec.email = ['abhisinghabhimanyu@gmail.com']

  spec.homepage = 'https://github.com/avmnu-sng/clepsydra'
  spec.summary = 'Instrument events for elapsed time'
  spec.description = <<-DESCRIPTION.strip.gsub(/\s+/, ' ')
    Clepsydra is an instrumentation tool allowing instrumenting events.
    You can subscribe to events to receive instrument notifications once done.
  DESCRIPTION
  spec.license = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = "https://github.com/avmnu-sng/clepsydra/tree/v#{spec.version}"
  spec.metadata['changelog_uri'] = 'https://github.com/avmnu-sng/clepsydra/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/avmnu-sng/clepsydra/issues'

  spec.required_ruby_version = '>= 2.5.0'
  spec.add_dependency 'concurrent-ruby', '~> 1.0', '>= 1.0.0'

  spec.files = `git ls-files -- lib/*`.chomp.split("\n")
  spec.files += %w[CHANGELOG.md README.md LICENSE]
  spec.require_paths = ['lib']
end
