require 'vidibus/watch_folder/util'
require 'vidibus/watch_folder/base'
require 'vidibus/watch_folder/job'
require 'vidibus/watch_folder/railtie' if defined?(Rails::Railtie)

require 'listen'

module Vidibus
  module WatchFolder
    extend self

    class Error < StandardError; end
    class NoRootsError < Error; end

    EVENTS = %w[added modified removed]

    attr_accessor :roots, :logger, :autoload_paths
    @roots = []
    @logger = Logger.new(STDOUT)
    @autoload_paths = []

    # Calculate checksum of given file path
    def checksum(path)
      Digest::SHA2.file(path).hexdigest
    end

    # Listen for changes within all roots
    def listen
      autoload
      unless roots.any?
        raise NoRootsError, 'No folders to watch!'
      end
      roots.uniq!
      roots_regex = /(?:#{roots.join('|')})/
      logger.debug("Vidibus::WatchFolder.listen to #{roots.join(',')}")
      args = roots + [{:latency => 0.1}]
      Listen.to(*args) do |modified, added, removed|
        EVENTS.each do |event|
          eval(event).each do |path|
            begin
              uuid = path[/^#{roots_regex}\/([^\/]+)\/.+$/, 1] || next
              begin
                Base.find_by_uuid(uuid).handle(event, path)
              rescue Mongoid::Errors::DocumentNotFound
              end
            rescue => e
              logger.error("ERROR in Vidibus::WatchFolder.listen:\n#{e.inspect}\n--\n#{e.backtrace.join("\n")}")
            end
          end
        end
      end
    end

    # Constantize all watch folder class names to trigger autoloading.
    def autoload
      return unless autoload_paths.any?
      list = Dir[*autoload_paths].map do |f|
        File.read(f)[/class ([^<]+) < Vidibus::WatchFolder::Base/, 1]
      end.compact.map { |k| k.constantize }
    end
  end
end
