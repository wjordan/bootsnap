class FetchCache
  class << self
    attr_accessor :cache
  end

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

  def fetch(path)
    data, cached_file_key = cache.get(path)
    file_key = self.file_key.call(path)
    if file_key == cached_file_key
      data
    else
      new_data = yield path
      cache.set(path, [new_data, file_key])
      new_data
    end
  end
end
