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

      module InstructionSequenceMixin
        def load_iseq(path)
          binary = ISeq.cache.fetch(path) do |data|
            begin
              RubyVM::InstructionSequence.compile(data, path, path).to_binary
            rescue SyntaxError
              raise Uncompilable, 'syntax error'
            end
          end
          RubyVM::InstructionSequence.load_from_binary(binary)
        rescue RuntimeError => e
          if e.message == 'broken binary format'
            STDERR.puts "[Bootsnap::CompileCache] warning: rejecting broken binary"
            return nil
          else
            raise
          end
        end

        def compile_option=(hash)
          super(hash)
          Bootsnap::CompileCache::ISeq.compile_option_updated
        end
      end

      def self.compile_option_updated
        option = RubyVM::InstructionSequence.compile_option
        crc = Zlib.crc32(option.inspect)
        Bootsnap::CompileCache::Native.compile_option_crc32 = crc
        Cache.compile_option = crc.to_s
      end

      def self.install!(cache = nil)
        self.cache = if cache.is_a?(CacheWrapper::Wrapper)
          Cache.new(cache)
        else
          require 'bootsnap/cache/xattr_cache'
          XattrCache.new
        end

        Bootsnap::CompileCache::ISeq.compile_option_updated
        class << RubyVM::InstructionSequence
          prepend InstructionSequenceMixin
        end
      end
    end
  end
end
