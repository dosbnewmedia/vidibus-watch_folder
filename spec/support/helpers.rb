def reset_roots
  Vidibus::WatchFolder.roots = []
end

def cleanup_watched
  entries = Dir['spec/support/watched/*'].reject { |e| e == '.gitkeep' }
  FileUtils.rm_r(entries)
end
