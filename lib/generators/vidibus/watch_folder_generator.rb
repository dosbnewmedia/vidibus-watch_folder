require 'rails/generators'
require 'rails/generators/named_base'

module Vidibus
  class WatchFolderGenerator < Rails::Generators::Base

    self.source_paths << File.join(File.dirname(__FILE__), 'templates')

    def create_script_file
      template 'script', 'script/watch_folder'
      chmod 'script/watch_folder', 0755
    end
  end
end
