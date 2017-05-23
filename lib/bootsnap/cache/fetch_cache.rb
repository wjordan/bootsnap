class FetchCache
  attr_accessor :cache

  def initialize(cache)
    self.cache = cache
  end

  def self.file_key(path)
    [
      path,
      File.mtime(path).to_i,
      RUBY_VERSION,
      Bootsnap::VERSION
    ].join
  end

  # Fetch cached, processed contents from a file path.
  # fetch(path) {|contents| block } -> obj
  def fetch(path)
    data, cached_file_key = cache.get(path)
    file_key = self.class.file_key(path)
    if file_key == cached_file_key
      data
    else
      new_data = yield File.read(path)
      cache.set(path, [new_data, file_key])
      new_data
    end
  end
end
