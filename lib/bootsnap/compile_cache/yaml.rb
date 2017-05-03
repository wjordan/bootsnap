module Bootsnap
  module CompileCache
    module YAML
      class << self
        attr_accessor :cache
      end

      def load_file(path)
        cache.fetch(path) do
          super(path)
        end
      end

      def self.install!(cache)
        self.cache = if cache.is_a?(Bootsnap::CacheWrapper)
          require 'bootsnap/cache/fetch_cache'
          FetchCache.new(cache)
        else
          require 'bootsnap/cache/xattr_cache'
          XattrCache.new
        end
        require 'yaml'
        ::YAML.singleton_class.prepend Bootsnap::CompileCache::YAML
      end
    end
  end
end
