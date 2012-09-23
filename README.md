# Vidibus::WatchFolder [![](http://travis-ci.org/vidibus/vidibus-watch_folder.png)](http://travis-ci.org/vidibus/vidibus-watch_folder)

This gem lets you create multipe watch folders within your application, e.g. to provide individual FTP mount points for customers.

To store each watch folder configuration, [Mongoid](http://mongoid.org/en/mongoid/index.html) (~> 2.5) is used. Files are processed asynchronously with [DelayedJob](https://github.com/collectiveidea/delayed_job).

This gem is part of [Vidibus](http://vidibus.org), an open source toolset for building distributed (video) applications.


## Installation

Add `gem 'vidibus-watch_folder'` to the Gemfile of your application. Then call `bundle install` on your console.

This gem relies on [Listen](https://github.com/guard/listen) to detect changes. If you're on Windows, you'll want to install an additional file system adapter to increase performance:

```ruby
# Windows only!
gem 'wdm', '~> 0.0.3'
```


### Logging

In order to redirect logging output to the Rails log, you may equip `initializers/watch_folder.rb` with this content:

```ruby
Vidibus::WatchFolder.logger = Rails.logger
```


## Usage

### Models

Setting up a custom watch folder model is easy. Since it's a `Mongoid::Document`, all of the `ActiveModel` magic is at your disposal. Just add some watch folder settings:

```ruby
class Example < Vidibus::WatchFolder::Base

  # Define a root directory to store files in.
  root '/some/path'

  # Define folders that should automatically be created.
  folders 'in', 'out'

  # Define callbacks to perform when files change.
  #
  # Use filter :when to define events to watch. Supported event types are:
  #   :added+, :modified, :removed
  #
  # Add filter :delay to perform callback later. Execution will be delayed
  # until the watched file will not have been changed for given period of time.
  # This is useful for waiting until an upload is completed.
  #
  # Provide :folders to limit this callback to certain folders.
  callback :create_upload, {
    :when => :added,
    :delay => 1.minute,
    :folders => 'in'
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
example.path   # => '/some/path/98fe6010e7b5012f7e4c6c626d58b44c/'
example.files  # => ['<FILE_PATH>', ...]

# Destroy the instance (will remove its path, too)
example.destroy
```


### Listening for file changes

File changes are detected by performing `Vidibus::WatchFolder.listen`. Beware, this method is blocking, so better spawn a daemon.


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

&copy; 2012 André Pankratz. See LICENSE for details.
