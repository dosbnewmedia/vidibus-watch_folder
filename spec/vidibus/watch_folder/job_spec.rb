require 'spec_helper'

describe Vidibus::WatchFolder::Job do
  let(:root) { File.expand_path('spec/support/watched') }
  let(:watch_folder) do
    Vidibus::WatchFolder::Base.config = {:root => root}
    Vidibus::WatchFolder::Base.create
  end

  let(:path) do
    File.expand_path("spec/support/watched/#{watch_folder.uuid}/some.txt")
  end
  let(:this) do
    args = [watch_folder.uuid, 'added', path, '<checksum>', 42]
    Vidibus::WatchFolder::Job.new(*args)
  end

  describe '#validate!' do
    it 'should raise no error if all arguments are provided' do
      expect { this.validate! }.not_to raise_error
    end

    it 'should raise an error if arguments are missing' do
      expect { Vidibus::WatchFolder::Job.new.validate! }.
        to raise_error(ArgumentError, 'Provide UUID, event, path, checksum, and an optional delay')
    end
  end

  describe '#enqueue!' do
    context 'on a job with delay' do
      it 'should create a delayed job with delay and return its id' do
        stub_time
        id = BSON::ObjectId('4e4cda52fe197f7e19000001')
        mock(Delayed::Job).enqueue(this, :run_at => Time.now+42) do
          Struct.new(:id).new(id)
        end
        this.enqueue!.should eq(id)
      end
    end

    context 'on a job without delay' do
      let(:this) do
        args = [watch_folder.uuid, 'added', path, '<checksum>', nil]
        Vidibus::WatchFolder::Job.new(*args)
      end

      it 'should create a delayed job without delay and return its id' do
        stub_time
        id = BSON::ObjectId('4e4cda52fe197f7e19000001')
        mock(Delayed::Job).enqueue(this) do
          Struct.new(:id).new(id)
        end
        this.enqueue!.should eq(id)
      end
    end
  end

  describe '#perform' do
    it 'should call #handle on watch folder instance' do
      mock(Vidibus::WatchFolder::Base).find_by_uuid(watch_folder.uuid) { this }
      mock(this).handle('added', path, '<checksum>')
      this.perform
    end

    it 'should fail silently if WatchFolder does not exist' do
      mock(Vidibus::WatchFolder::Base).find_by_uuid(watch_folder.uuid) do
        raise Mongoid::Errors::DocumentNotFound.new(Vidibus::WatchFolder::Base, :uuid => watch_folder.uuid)
      end
      expect { this.perform }.not_to raise_error
    end
  end
end
