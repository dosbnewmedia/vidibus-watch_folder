begin
  require 'daemons'
rescue LoadError
  raise %(Please add `gem 'daemons' gem to your Gemfile for this to work)
end
require 'optparse'

module Vidibus
  module WatchFolder
    class Daemon

      def initialize(args)
        @options = {:pid_dir => "#{Rails.root}/tmp/pids"}
        options = OptionParser.new do |options|
          options.banner = "Usage: #{File.basename($0)} start|stop|restart"
          options.on('-h', '--help', 'Show this message') do
            puts options
            exit 1
          end
        end
        @args = options.parse!(args)
      end

      def daemonize
        dir = @options[:pid_dir]
        Dir.mkdir(dir) unless File.exists?(dir)
        run_process('watch_folder', dir)
      end

      def run_process(name, dir)
        Daemons.run_proc(name, :dir => dir, :dir_mode => :normal) { run }
      end

      def run
        Dir.chdir(Rails.root)
        log = File.join(Rails.root, 'log', 'watch_folder.log')
        Vidibus::WatchFolder.logger = ActiveSupport::BufferedLogger.new(log)
        Vidibus::WatchFolder.listen
      rescue => e
        Vidibus::WatchFolder.logger.fatal(e)
        STDERR.puts(e.message)
        exit 1
      end
    end
  end
end
