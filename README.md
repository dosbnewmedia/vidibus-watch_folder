# Vidibus::WatchFolder [![Build Status](https://travis-ci.org/vidibus/vidibus-watch_folder.png)](https://travis-ci.org/vidibus/vidibus-watch_folder)

This gem lets you create multipe watch folders within your application, e.g. to provide individual FTP mount points for customers, maybe in combination with [Vidibus::Pureftpd](https://github.com/vidibus/vidibus-pureftpd).

To store each watch folder configuration, [Mongoid](http://mongoid.org/en/mongoid/index.html) (>= 3) is used. Files are processed asynchronously with [DelayedJob](https://github.com/collectiveidea/delayed_job).

This gem is part of [Vidibus](http://vidibus.org), an open source toolset for building distributed (video) applications.


## Installation

Add `gem 'vidibus-watch_folder'` to the Gemfile of your application. Then call `bundle install` on your console.

This gem relies on [Listen](https://github.com/guard/listen) to detect changes. If you're on Windows, you'll want to install an additional file system adapter to increase performance:

```ruby
# Windows only!
gem 'wdm', '~> 0.0.3'
```


## Usage

### Models

Setting up a custom watch folder model is easy. Since it's a `Mongoid::Document`, all of the `ActiveModel` magic is at your disposal. Just add some watch folder settings:

```ruby
class Example < Vidibus::WatchFolder::Base

  # Define a root directory to store files in.
  root Rails.root.join('examples')

  # Define folders that should automatically be created.
  folders 'in', 'out'

  # Define callbacks to perform when files change.
  #
  # Use filter :when to define events to watch. Supported event types are:
  #   :added, :modified, :removed
  #
  # Add filter :delay to perform callback later. Execution will be delayed
  # until the watched file will not have been changed for given period of time.
  # This is useful for waiting until an upload is completed.
  #
  # Set filter :ignore to exclude file names matching given regex.
  #
  # Provide :folders to limit this callback to certain folders.
  callback :create_upload, {
    :when => :added,
    :delay => 1.minute,
    :folders => 'in',
    :ignore => /^\.pureftpd-upload/
  }
  callback :destroy_upload, :when => :removed

  # Callback to process created files
  def create_upload(event, path)
    ...
  end

  # Callback to handle deleted files
  def destroy_upload(event, path)
    ...
  end
end
```


### Instances

Handling a watch folder instance is straightforward:

```ruby
example = Example.create

# Access instance properties
example.uuid   # => 98fe6010e7b5012f7e4c6c626d58b44c
example.path   # => '/path/to/rails/examples/98fe6010e7b5012f7e4c6c626d58b44c/'
example.files  # => ['<FILE_PATH>', ...]

# Destroy the instance (will remove its path, too)
example.destroy
```


### Listening for file changes

File changes are detected by performing `Vidibus::WatchFolder.listen`. Beware, this method is blocking, so better spawn the daemon.


#### Listener daemon

To run the listener as daemon, this gem provides a shell script. Install it with

```
rails g vidibus:watch_folder
```

The daemon requires that `gem 'daemons'` is installed. To spawn him, enter

```
script/watch_folder start
```

#### Possible caveat

To collect the paths to listen to, `Vidibus::WatchFolder.listen` requires that all classes inheriting `Vidibus::WatchFolder::Base` have been loaded.

Because Rails is autoloading almost everything in development, this requirement is not met without the help of a little hack: To trigger autoloading, the listener collects all aforementioned class names from the `app` directory and constantizes them.

**So here's the caveat:** If you define watch folder models outside of the `app` directory, you'll have to let the listener know. An initializer is perfect for that:

```ruby
# Collect all watch folder models in lib, too
Vidibus::WatchFolder.autoload_paths << '/lib/**/*.rb'
```


## Deployment

A Capistrano configuration is included. Require it in your Capistrano `config.rb`.

```ruby
require 'vidibus/watch_folder/capistrano'
```

That will add a bunch of callback hooks.

```ruby
after 'deploy:stop',    'vidibus:watch_folder:stop'
after 'deploy:start',   'vidibus:watch_folder:start'
after 'deploy:restart', 'vidibus:watch_folder:restart'
```

If you need more control over the callbacks, you may load just the recipes without the hooks.

```ruby
require 'vidibus/watch_folder/capistrano/recipes'
```


### Shared folders

In case you want to put files into a shared folder, you may run into a validation issue. Here's a configuration for our watch folder example that gets symlinked with a twist:

```ruby
namespace :examples do
  task :setup do
    path = File.join(shared_path, 'examples')
    run "mkdir -p #{path}"
    run "chmod -R 777 #{path}"
  end

  task :symlink do
    run "ln -nfs #{shared_path}/examples #{release_path}/"
  end
end

after 'deploy:setup', 'examples:setup'
before 'deploy:assets:precompile', 'examples:symlink'
```

The important thing is the last line. Instead of the usual `after 'deploy:update_code'` hook we're triggering the symlink on `before 'deploy:assets:precompile'`. The reason is that precompiling initializes the Rails app which will fail if the example directory does not exist yet.


## Testing

To test this gem, call `bundle install` and `bundle exec rspec spec` on your console.

When testing your application you may want to define a different root path for your watch folder models. Just override them somewhere in your test files, for example in `spec_helper.rb`:

```ruby
# Set different root for watch folder example
Example.root('spec/support/examples')
```

Make sure that directory exists. From your Rails root call:

```
mkdir spec/support/examples
touch spec/support/examples/.gitkeep
```

To clean up the test folders, add the following to your RSpec config:

```ruby
RSpec.configure do |config|
  config.before(:each) do
    FileUtils.rm_r(Dir['spec/support/examples/*'].reject {|e| e == '.gitkeep'})
  end
end
```


## Copyright

&copy; 2012-2013 André Pankratz. See LICENSE for details.
