require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'rr'
require 'vidibus-watch_folder'

Dir[File.expand_path('spec/support/**/*.rb')].each { |f| require f }

# Silence logger
Vidibus::WatchFolder.logger = Logger.new('/dev/null')

Mongoid.configure do |config|
  name = 'vidibus-watch_folder_test'
  host = 'localhost'
  config.master = Mongo::Connection.new.db(name)
  # Display MongoDB logs for debugging:
  # config.master = Mongo::Connection.new("localhost", 27017, :logger => Logger.new($stdout, :info)).db(name)
  config.logger = nil
end

RSpec.configure do |config|
  config.mock_with :rr
  config.before(:each) do
    Mongoid.master.collections.select {|c| c.name !~ /system/}.each(&:drop)
  end
end
