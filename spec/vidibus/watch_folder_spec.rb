require 'spec_helper'

describe Vidibus::WatchFolder do
  let(:this) { Vidibus::WatchFolder }

  before do
    reset_roots
    cleanup_watched
  end

  describe '.roots' do
    it 'should be an empty array by default' do
      this.roots.should eq([])
    end

    it 'should be appendable' do
      this.roots << 'whatever'
      this.roots.should eq(['whatever'])
    end
  end

  describe '.checksum' do
    it 'should return checksum of a file' do
      path = 'spec/support/watched/something.txt'
      FileUtils.touch(path)
      Vidibus::WatchFolder.checksum(path).should eq('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
    end
  end

  describe '.listen' do
    it 'should raise an error if no roots have been defined' do
      expect { this.listen }.to raise_error(Vidibus::WatchFolder::NoRootsError, 'No folders to watch!')
    end

    context 'with existing roots' do
      let(:root) { File.expand_path('spec/support/watched') }
      let(:instance) do
        Vidibus::WatchFolder::Base.config = {:root => root}
        Vidibus::WatchFolder::Base.create
      end

      before do
        this.roots << root
      end

      let(:path) { "#{instance.path}/in/whatever" }

      it 'should detect new files in each root' do
        args = this.roots + [{:latency => 0.1}]
        mock(Listen).to(*args)
        this.listen
      end

      it 'should autoload classes' do
        mock(this).autoload
        stub(Listen).to.with_any_args.yields([], [path], [])
        this.listen
      end

      it 'should find the appropriate watch folder instance' do
        mock(Vidibus::WatchFolder::Base).find_by_uuid(instance.uuid) do
          instance
        end
        stub(instance).handle.with_any_args
        stub(Listen).to.with_any_args.yields([], [path], [])
        this.listen
      end

      it 'should not fail if path is invalid' do
        path = File.expand_path('spec/support/watched/_invalid_/in/whatever')
        stub(Listen).to.with_any_args.yields([], [path], [])
        expect { this.listen }.not_to raise_error
      end

      it 'should log exceptions' do
        stub(Vidibus::WatchFolder::Base).find_by_uuid(instance.uuid) do
          raise 'That went wrong'
        end
        stub(Listen).to.with_any_args.yields([], [path], [])
        mock(this.logger).error.with_any_args
        expect { this.listen }.not_to raise_error
      end

      it 'should call #handle on matching watch folder instance' do
        stub(Vidibus::WatchFolder::Base).find_by_uuid(instance.uuid) do
          instance
        end
        mock(instance).handle('added', path)
        stub(Listen).to.with_any_args.yields([], [path], [])
        this.listen
      end

      context 'with path_mapping defined' do
        after do
          Vidibus::WatchFolder.path_mapping = []
        end

        it 'should work if path_mapping is correct' do
          Vidibus::WatchFolder.path_mapping << [/.+\/vidibus-watch_folder\/spec\//, '.+']
          mock(Vidibus::WatchFolder::Base).find_by_uuid(instance.uuid) do
            instance
          end
          stub(instance).handle.with_any_args
          stub(Listen).to.with_any_args.yields([], [path], [])
          this.listen
        end

        it 'should not work if path_mapping is wrong' do
          Vidibus::WatchFolder.path_mapping << [/.+\/vidibus-watch_folder\/spec\//, '_broken_']
          dont_allow(Vidibus::WatchFolder::Base).with_any_args
          stub(Listen).to.with_any_args.yields([], [path], [])
          this.listen
        end
      end
    end
  end

  context 'with path_mapping defined' do
      let(:root) { File.expand_path('spec/support/watched') }
      let(:instance) do
        Vidibus::WatchFolder::Base.config = {:root => root}
        Vidibus::WatchFolder::Base.create
      end
    Vidibus::WatchFolder.path_mapping
  end

  describe '.autoload' do
    it 'should do noting unless autoload paths have been defined' do
      dont_allow(Dir)[]
      this.autoload
    end

    it 'should return all watch folder classes in autoload paths' do
      this.autoload_paths << 'spec/support/*.rb'
      this.autoload.should eq([Example])
    end
  end
end
