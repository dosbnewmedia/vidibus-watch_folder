# Capistrano Recipes for watching folders.
#
# Load this file from your Capistrano config.rb:
# require 'vidibus/watch_folder/capistrano/recipes'
#
# Add these callbacks to have the watch_folder process restart when the server
# is restarted:
#
#   after 'deploy:stop',    'vidibus:watch_folder:stop'
#   after 'deploy:start',   'vidibus:watch_folder:start'
#   after 'deploy:restart', 'vidibus:watch_folder:restart'
#
Capistrano::Configuration.instance.load do
  namespace :vidibus do
    namespace :watch_folder do
      def rails_env
        fetch(:rails_env, false) ? "RAILS_ENV=#{fetch(:rails_env)}" : ''
      end

      def roles
        fetch(:app)
      end

      desc 'Stop the watch_folder process'
      task :stop, :roles => lambda { roles } do
        run "cd #{current_path};#{rails_env} script/watch_folder stop"
      end

      desc 'Start the watch_folder process'
      task :start, :roles => lambda { roles } do
        run "cd #{current_path};#{rails_env} script/watch_folder start"
      end

      desc 'Restart the watch_folder process'
      task :restart, :roles => lambda { roles } do
        run "cd #{current_path};#{rails_env} script/watch_folder restart"
      end
    end
  end
end
