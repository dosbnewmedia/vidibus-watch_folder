require 'mongoid'
require 'digest'
require 'vidibus-uuid'

module Vidibus
  module WatchFolder
    class Base
      include Mongoid::Document
      include Vidibus::Uuid::Mongoid

      class ConfigError < Error; end

      after_create :setup
      after_destroy :teardown

      # Return the configured root path
      def root
        self.class.config[:root] || raise(ConfigError, 'No root configured')
      end

      # Return the absolute path to this watch folder.
      def path
        File.join(root, uuid) if uuid
      end

      # Return a list of file paths within this watch folder.
      def files
        Dir["#{path}/**/*"].reject do |entry|
          File.directory?(entry)
        end
      end

      # Handle event for given file path.
      # Unless a checksum is provided, a asynchronous job will be started.
      # If provided checksum matches the current one (or if execution
      # shall not be delayed), appropriate callbacks will be performed.
      def handle(event, file_path, last_checksum = nil)
        return unless File.exist?(file_path) && !File.directory?(file_path)
        callbacks = self.class.config[:callback]
        callbacks.each do |folder, handlers|
          unless folder == :any
            pattern = %r(^#{path}/#{folder}/.+$)
            next unless file_path[pattern]
          end
          matching = handlers.select { |c| c[:when].include?(event) }
          matching.each do |handler|
            checksum ||= Vidibus::WatchFolder.checksum(file_path)
            delay = handler[:delay]
            if checksum == last_checksum || (last_checksum && !delay)
              send(handler[:method], event, file_path)
            else
              Job.create(uuid, event, file_path, checksum, delay)
            end
          end
        end
      end

      class << self

        # Set root path of this kind of watch folder.
        def root(path)
          path = File.expand_path(path)
          unless Util::Directory.valid?(path)
            raise ConfigError, 'Given root must be a folder'
          end
          unless Vidibus::WatchFolder.roots.include?(path)
            Vidibus::WatchFolder.roots << path
          end
          config[:root] = path
        end

        # Define folders to create automatically when an instance of this
        # kind of watch folder is created.
        def folders(*args)
          raise ConfigError, 'Define folders' unless args.any?
          config[:folders] = string_list(args)
        end

        # Define callbacks to perform when files change.
        #
        # Add filter :when to define events to watch. Supported event types
        # are :added, :modified, an :removed
        #
        # Add filter :delay to perform callback later. Execution will then be
        # delayed until the watched file will not have been changed for given
        # period of time. This is useful for waiting until an upload is
        # completed. If no delay has been configured, execution will be
        # asynchronous nonetheless.
        #
        # Provide :folders to limit this callback to certain folders.
        def callback(method, options = {})
          config[:callback] ||= {}
          opts = {:method => method}
          if events = events_options(options)
            opts[:when] = events
          end
          if delay = delay_options(options)
            opts[:delay] = delay
          end
          folders_options(options).each do |folder|
            config[:callback][folder] ||= []
            config[:callback][folder] << opts
          end
        end

        # Inheritable getter for config.
        def config
          @config ||= {}
        end

        # Inheritable setter for config.
        def config=(value)
          @config = value
        end

        # Find an instance of this kind of watch folder by its UUID.
        # Will raise an exception if no instance can be found.
        def find_by_uuid(uuid)
          found = where(:uuid => uuid).first || begin
            raise(Mongoid::Errors::DocumentNotFound.new(self, :uuid => uuid))
          end
        end

        private

        def string_list(input)
          Array(input).map { |i| i.to_s }
        end

        def folders_options(options)
          list = string_list(options.delete(:folders))
          list = [:any] unless list.any?
          list
        end

        def events_options(options)
          return unless events = string_list(options.delete(:when))
          if events.any?
            if (events-EVENTS).any?
              raise ConfigError, "Only these events are supported: #{EVENTS}"
            end
            return events
          end
          nil
        end

        def delay_options(options)
          return unless delay = options.delete(:delay)
          unless delay.is_a?(Integer) && delay > 0
            raise ConfigError, 'Delay must be defined in seconds'
          end
          delay
        end
      end

      private

      def setup
        setup_path
        setup_folders
      end

      def setup_path
        FileUtils.mkdir_p(path)
      end

      def setup_folders
        folders = self.class.config[:folders]
        return unless folders
        folders.each do |folder|
          FileUtils.mkdir_p(File.join(path, folder))
        end
      end

      def teardown
        unless path.to_s.length > 5
          raise ConfigError, "#{path} is too short! Exiting for security reasons."
        end
        FileUtils.rm_r(path) if File.exist?(path)
      end
    end
  end
end
