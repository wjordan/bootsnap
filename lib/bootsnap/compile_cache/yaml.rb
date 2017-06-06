require 'bootsnap/cache/fetch_cache'
module Bootsnap
  module CompileCache
    module YAML
      class << self
        attr_accessor :cache
      end

      def load_file(path)
        YAML.cache.fetch(path) do |_, file_path|
          super(file_path)
        end
      end

      def self.install!(cache)
        self.cache = if cache.is_a?(CacheWrapper::Wrapper)
          FetchCache.new(cache)
        else
          require 'bootsnap/cache/native_fetch_cache'
          NativeFetchCache.new(cache)
        end

        require 'yaml'
        ::YAML.singleton_class.prepend Bootsnap::CompileCache::YAML
      end
    end
  end
end
