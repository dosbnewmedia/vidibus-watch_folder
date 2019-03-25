# encoding: utf-8
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'vidibus/watch_folder/version'

Gem::Specification.new do |s|
  s.name        = 'vidibus-watch_folder'
  s.version     = Vidibus::WatchFolder::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = 'André Pankratz'
  s.email       = 'andre@vidibus.com'
  s.homepage    = 'https://github.com/vidibus/vidibus-watch_folder'
  s.summary     = 'Watch folders based on Mongoid with asynchronous processing'
  s.description = 'Create multiple watch folders within your application, e.g. to provide individual FTP mount points for customers.'
  s.license     = 'MIT'

  s.required_rubygems_version = '>= 1.3.6'
  s.required_ruby_version = '>= 2.0.0'
  s.rubyforge_project         = 'vidibus-watch_folder'

  s.add_dependency 'mongoid', '~> 3'
  s.add_dependency 'listen', '~> 0.5'
  s.add_dependency 'rb-fsevent', '~> 0.9.1'
  s.add_dependency 'rb-inotify', '~> 0.8.8'
  s.add_dependency 'vidibus-uuid'
  s.add_dependency 'delayed_job_mongoid'

  s.add_development_dependency 'bundler', '>= 1.0.0'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'rspec', '~> 2'
  s.add_development_dependency 'rr'

  s.files = Dir.glob('{lib,app,config}/**/*') + %w[LICENSE README.md Rakefile]
  s.require_path = 'lib'
end
