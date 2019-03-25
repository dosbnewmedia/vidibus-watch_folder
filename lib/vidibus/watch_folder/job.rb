require 'delayed_job_mongoid'

module Vidibus
  module WatchFolder
    class Job < Struct.new(:uuid, :event, :path, :checksum, :delay)
      def enqueue!
        validate!
        args = [self]
        i = delay.to_i
        if i > 0
          args << {:run_at => Time.now+i}
        end
        Delayed::Job.enqueue(*args).id
      end

      def perform
        begin
          watch_folder.handle(event, path, checksum)
        rescue Mongoid::Errors::DocumentNotFound
        end
      end

      def validate!
        return if uuid && event && path && checksum
        raise ArgumentError, 'Provide UUID, event, path, checksum, and an optional delay'
      end

      class << self
        def create(*args)
          new(*args).enqueue!
        end

        def delete_all(uuid, event, path)
          regex = /Vidibus::WatchFolder::Job\s*\nuuid: #{uuid}\nevent: #{event}\npath: "#{path}"\n/
          Delayed::Backend::Mongoid::Job.delete_all(:handler => regex)
        end
      end

      private

      def watch_folder
        Base.find_by_uuid(uuid)
      end
    end
  end
end
