require 'bootsnap/bootsnap'
require 'bootsnap/cache/fetch_cache'
require 'zlib'

module Bootsnap
  module CompileCache
    module ISeq
      class Cache < FetchCache
        class << self
          attr_accessor :compile_option
        end

        def self.file_key(path)
          super(path) + compile_option
        end
      end

      class << self
        attr_accessor :cache
      end

      def load_iseq(path)
        binary = ISeq.cache.fetch(path) do |data|
          RubyVM::InstructionSequence.compile(data).to_binary
        end
        RubyVM::InstructionSequence.load_from_binary(binary)
      rescue => e
        STDERR.puts "[Bootsnap::CompileCache] couldn't load: #{path}, #{e}"
        nil
      end

      def compile_option=(hash)
        super(hash)
        ISeq.compile_option_updated
      end

      def self.compile_option_updated
        option = RubyVM::InstructionSequence.compile_option
        crc = Zlib.crc32(option.inspect)
        Bootsnap::CompileCache::Native.compile_option_crc32 = crc
        Cache.compile_option = crc
      end

      def self.install!(cache)
        self.cache = if cache.is_a?(Bootsnap::CacheWrapper)
          FetchCache.new(cache)
        else
          require 'bootsnap/cache/xattr_cache'
          XattrCache.new
        end

        self.compile_option_updated
        RubyVM::InstructionSequence.singleton_class.prepend Bootsnap::CompileCache::ISeq
      end
    end
  end
end
