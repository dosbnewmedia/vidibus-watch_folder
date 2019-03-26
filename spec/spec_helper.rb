require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'vidibus-watch_folder'

Dir[File.expand_path('spec/support/**/*.rb')].each { |f| require f }

# Silence logger
Vidibus::WatchFolder.logger = Logger.new('/dev/null')

Mongoid.configure do |config|
  config.connect_to('vidibus-watch_folder_test')
end

RSpec.configure do |config|
  config.before(:each) do
    Mongoid::Sessions.default.collections.select do |c|
      c.name !~ /system/
    end.each(&:drop)
  end

  config.after(:each) do
    Delayed::Backend::Mongoid::Job.destroy_all
  end
end
