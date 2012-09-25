require 'spec_helper'

describe Vidibus::WatchFolder::Base do
  let(:klass) { Vidibus::WatchFolder::Base }
  let(:instance) do
    klass.config = {
      :root => File.expand_path('spec/support/watched'),
      :folders => ['in', 'out'],
      :callback => {
        'in' => [{:method => :process, :delay => 42, :when => ['added']}],
        :any => [{:method => :process, :when => ['removed'], :ignore => /flv/}]
      }
    }
    klass.create
  end
  let(:in_file_path) { File.join(instance.path, 'in', 'some.flv') }
  let(:out_file_path) { File.join(instance.path, 'out', 'thing.mp4') }

  before do
    reset_roots
    klass.config = {}
  end

  describe 'creating' do
    it 'should set up the path' do
      File.exist?(instance.path).should be_true
    end

    it 'should set up folders within path' do
      Dir.entries(instance.path).sort.should eq(%w[. .. in out])
    end

    it 'should raise an error if no root has been configured' do
      klass.config = {
        :folders => ['in', 'out']
      }
      expect { klass.create }.to raise_error(klass::ConfigError)
    end

    it 'should not fail if no folders have been configured' do
      klass.config = {
        :root => File.expand_path('spec/support/watched')
      }
      klass.create
    end
  end

  describe 'destroying' do
    it 'should remove the path' do
      instance.destroy
      File.exist?(instance.path).should be_false
    end

    it 'should raise an error if path is very short (for security reasons)' do
      stub(instance).path { '/tmp/' }
      expect { instance.destroy }.
        to raise_error(klass::ConfigError, '/tmp/ is too short! Exiting for security reasons.')
    end
  end

  describe '#root' do
    it 'should return the configured root' do
      instance.root.should eq(klass.config[:root])
    end

    it 'should raise an error unless root has been configured' do
      expect { klass.new.root }.
        to raise_error(klass::ConfigError, 'No root configured')
    end
  end

  describe '#path' do
    it 'should be an absolute path containing the UUID' do
      path = File.expand_path("spec/support/watched/#{instance.uuid}")
      instance.path.should eq(path)
    end

    it 'should return nil unless instance has a UUID' do
      klass.new.path.should be_nil
    end
  end

  describe '#files' do
    it 'should be a blank array by default' do
      instance.files.should be_blank
    end

    it 'should contain a list of files within folder' do
      files = [
        "#{instance.path}/in/whatever",
        "#{instance.path}/out/it/takes",
      ]
      FileUtils.mkdir_p("#{instance.path}/out/it/")
      files.each { |f| FileUtils.touch(f) }
      instance.files.should eq(files)
    end
  end

  describe '#handle' do
    let(:path) { in_file_path }

    before do
      stub(Vidibus::WatchFolder).checksum(path) { '<checksum>' }
    end

    it 'should raise an error when called without arguments' do
      expect { instance.handle }.to raise_error(ArgumentError)
    end

    it 'should work with event and path' do
      expect { instance.handle('modified', path) }.
        not_to raise_error(ArgumentError)
    end

    it 'should work with event, path, and checksum' do
      expect { instance.handle('modified', path, '<checksum>') }.
        not_to raise_error(ArgumentError)
    end

    it 'should return unless file exists' do
      mock(File).exist?(path) { false }
      dont_allow(Vidibus::WatchFolder).checksum
      instance.handle('modified', path)
    end

    it 'should return if file is a directory' do
      stub(File).exist?(path) { true }
      mock(File).directory?(path) { true }
      dont_allow(Vidibus::WatchFolder).checksum
      instance.handle('modified', path)
    end

    context 'valid file input' do
      before do
        stub(File).exist?(path) { true }
        stub(File).directory?(path) { false }
      end

      context 'when called without checksum' do
        context 'with an instant callback configured for event type' do
          let(:path) { out_file_path }

          it 'should create a job without delay' do
            args = [instance.uuid, 'removed', path, '<checksum>', nil]
            mock(Vidibus::WatchFolder::Job).create(*args)
            instance.handle('removed', path)
          end
        end

        context 'with a delayed callback configured for event type' do
          it 'should create a job with delay' do
            args = [instance.uuid, 'added', path, '<checksum>', 42]
            mock(Vidibus::WatchFolder::Job).create(*args)
            instance.handle('added', path)
          end

          it 'should not trigger the callback' do
            dont_allow(instance).process.with_any_args
            instance.handle('added', path)
          end
        end

        context 'without callbacks configured for event type' do
          it 'should do noting' do
            dont_allow(Vidibus::WatchFolder::Job).create
            dont_allow(instance).process
            instance.handle('modified', path)
          end
        end

        context 'if file name should be ignored' do
          it 'should do noting' do
            dont_allow(Vidibus::WatchFolder::Job).create
            dont_allow(instance).process
            instance.handle('removed', path)
          end
        end
      end

      context 'when called with checksum' do
        context 'that equals the current one' do
          it 'should trigger the callback' do
            mock(instance).process('added', path)
            instance.handle('added', path, '<checksum>')
          end

          it 'should not create a job' do
            stub(instance).process.with_any_args
            dont_allow(Vidibus::WatchFolder::Job).create.with_any_args
            instance.handle('added', path, '<checksum>')
          end
        end

        context 'that differs from the current one' do
          context 'for a callback with delay' do
            it 'should create a job with current checksum' do
              args = [instance.uuid, 'added', path, '<checksum>', 42]
              mock(Vidibus::WatchFolder::Job).create(*args)
              instance.handle('added', path, '<different>')
            end

            it 'should not trigger the callback' do
              dont_allow(instance).process.with_any_args
              instance.handle('added', path, '<different>')
            end
          end

          context 'for a job without delay' do
            let(:path) { out_file_path }

            it 'should trigger the callback' do
              mock(instance).process('removed', path)
              instance.handle('removed', path, '<different>')
            end

            it 'should not create a job' do
              stub(instance).process.with_any_args
              dont_allow(Vidibus::WatchFolder::Job).create.with_any_args
              instance.handle('removed', path, '<different>')
            end
          end
        end
      end
    end
  end

  describe '.root' do
    it 'should require an attribute' do
      expect { klass.root }.to raise_error(ArgumentError)
    end

    it 'should raise an error if given argument is not a folder' do
      expect { klass.root('/does-not-exist') }.
        to raise_error(klass::ConfigError, 'Given root must be a folder')
    end

    it 'should not raise an error for valid relative paths' do
      expect { klass.root('spec/support/watched') }.
        not_to raise_error
    end

    it 'should not raise an error for valid absolute paths' do
      expect { klass.root(File.expand_path('spec/support/watched')) }.
        not_to raise_error
    end

    it 'should add an expanded path to roots collection' do
      path = 'spec/support/watched'
      klass.root(path)
      Vidibus::WatchFolder.roots.should include(File.expand_path(path))
    end

    it 'should store root in config' do
      klass.root('spec/support/watched')
      klass.config[:root].should eq(File.expand_path('spec/support/watched'))
    end

    it 'should not add a path twice' do
      path = 'spec/support/watched'
      klass.root(path)
      klass.root(path)
      Vidibus::WatchFolder.roots.should eq([File.expand_path(path)])
    end
  end

  describe '.folders' do
    it 'should require attributes' do
      expect { klass.folders }.to raise_error(klass::ConfigError)
    end

    it 'should accept simple strings as arguments' do
      expect { klass.folders('in', 'out') }.not_to raise_error(klass::ConfigError)
    end

    it 'should accept symbols as arguments' do
      expect { klass.folders(:in, :out) }.not_to raise_error(klass::ConfigError)
    end

    it 'should accept relative paths as arguments' do
      expect { klass.folders('in/special') }.not_to raise_error(klass::ConfigError)
    end

    it 'should store folders as strings in config' do
      klass.folders('in/special', :out)
      klass.config[:folders].should eq(['in/special', 'out'])
    end
  end

  describe '.callback' do
    it 'should require attributes' do
      expect { klass.callback }.to raise_error(ArgumentError)
    end

    it 'should store callback in config' do
      klass.callback(:whatever)
      klass.config[:callback].should_not be_nil
    end

    it 'should store callback for any folder, if none given' do
      klass.callback(:whatever)
      klass.config[:callback].should eq(
        :any => [{:method => :whatever}]
      )
    end

    it 'should store a delay' do
      klass.callback(:whatever, :delay => 1.minute)
      klass.config[:callback].should eq(
        :any => [{:method => :whatever, :delay => 60}]
      )
    end

    it 'should raise an error unless given delay is an integer' do
      expect { klass.callback(:whatever, :delay => 'some') }.
        to raise_error(klass::ConfigError, 'Delay must be defined in seconds')
    end

    it 'should store an ignore pattern' do
      klass.callback(:whatever, :ignore => /s.me/)
      klass.config[:callback].should eq(
        :any => [{:method => :whatever, :ignore => /s.me/}]
      )
    end

    it 'should raise an error unless ignore pattern is a regular expression' do
      expect { klass.callback(:whatever, :ignore => 'some') }.
        to raise_error(klass::ConfigError, 'Ignore pattern must be a regular expression')
    end

    it 'should store callback for a given folder' do
      klass.callback(:whatever, :folders => 'in')
      klass.config[:callback].should eq(
        'in' => [{:method => :whatever}]
      )
    end

    it 'should store callback for any valid event type' do
      klass.callback(:whatever, :when => ['added', 'modified'])
      klass.config[:callback].should eq(
        :any => [{:method => :whatever, :when => ['added', 'modified']}]
      )
    end

    it 'should raise an error if event type is invalid' do
      expect { klass.callback(:whatever, :when => ['whatever']) }.
        to raise_error(klass::ConfigError, "Only these events are supported: #{Vidibus::WatchFolder::EVENTS}")
    end

    it 'should store callback for a given folder' do
      klass.callback(:whatever, :folders => 'in')
      klass.config[:callback].should eq(
        'in' => [{:method => :whatever}]
      )
    end

    it 'should store callback for folders list' do
      klass.callback(:whatever, :folders => ['in', :out])
      klass.config[:callback].should eq(
        'in' => [{:method => :whatever}],
        'out' => [{:method => :whatever}]
      )
    end

    it 'should store callbacks for multiple folders' do
      klass.callback(:whatever, :folders => 'in')
      klass.callback(:it_takes, :folders => 'out')
      klass.config[:callback].should eq(
        'in' => [{:method => :whatever}],
        'out' => [{:method => :it_takes}]
      )
    end

    it 'should store multiple callbacks for a folder' do
      klass.callback(:whatever, :folders => 'in')
      klass.callback(:it_takes, :folders => 'in')
      klass.config[:callback].should eq(
        'in' => [
          {:method => :whatever},
          {:method => :it_takes}
        ]
      )
    end
  end

  describe '.config' do
    it 'should be accessible' do
      klass.config = 'whatever'
      klass.config.should eq('whatever')
    end
  end
end
