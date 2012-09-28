require 'vidibus/watch_folder/capistrano/recipes'

# Run Capistrano Recipes for watching folders.
#
# Load this file from your Capistrano config.rb:
# require 'vidibus/watch_folder/capistrano'
#
Capistrano::Configuration.instance.load do
  after 'deploy:stop',    'vidibus:watch_folder:stop'
  after 'deploy:start',   'vidibus:watch_folder:start'
  after 'deploy:restart', 'vidibus:watch_folder:restart'
end
