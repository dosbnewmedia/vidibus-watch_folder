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

    attr_accessor :roots, :logger, :autoload_paths, :path_mapping
    @roots = []
    @logger = Logger.new(STDOUT)
    @autoload_paths = []
    @path_mapping = []

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
      logger.debug("[#{Time.now.utc}] - Listening to #{roots.join(',')}")
      args = roots + [{:latency => 0.1}]
      Listen.to(*args) do |modified, added, removed|
        EVENTS.each do |event|
          eval(event).each do |path|
            logger.debug %([#{Time.now.utc}] - #{event}: #{path})
            begin
              uuid = path[/^#{roots_regex}\/([^\/]+)\/.+$/, 1] || next
              begin
                base = Base.find_by_uuid(uuid)
                base.handle(event, path)
              rescue Mongoid::Errors::DocumentNotFound
                logger.error %([#{Time.now.utc}] - Can't find Vidibus::WatchFolder::Base #{uuid})
              end
            rescue => e
              logger.error("[#{Time.now.utc}] - ERROR in Vidibus::WatchFolder.listen:\n#{e.inspect}\n---\n#{e.backtrace.join("\n")}")
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

    private

    # Return regular expression for root paths.
    #
    # If any path_mapping has been defined, that mapping will be applied.
    # That is often required to turn absolute path into relative ones in order
    # to avoid problems with symlinks, because uploaded files will usually go
    # into a shared directory but the root paths Rails reports are from within
    # the current release directory.
    def roots_regex
      @roots_regex ||= begin
        _roots = roots.join('|')
        path_mapping.each do |from, to|
          _roots.gsub!(from, to)
        end
        /(?:#{_roots})/
      end
    end
  end
end
