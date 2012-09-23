module Vidibus
  module WatchFolder
    module Util
      module Directory
        extend self

        # Check if path is a read- and writable directory.
        def valid?(path)
          File.exist?(path) &&
          File.directory?(path) &&
          File.readable?(path) &&
          File.writable?(path)
        end
      end
    end
  end
end
