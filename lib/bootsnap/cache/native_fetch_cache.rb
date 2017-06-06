require 'msgpack'

class NativeFetchHandler
  attr_accessor :msgpack_factory, :block, :path

  def initialize(&block)
    self.block = block

    # MessagePack serializes symbols as strings by default.
    # We want them to roundtrip cleanly, so we use a custom factory.
    # see: https://github.com/msgpack/msgpack-ruby/pull/122
    factory = MessagePack::Factory.new
    factory.register_type(0x00, Symbol)
    self.msgpack_factory = factory
  end

  # data is the source content of the file loaded from path
  def input_to_storage(data, path)
    obj = block.call(data, path)
    msgpack_factory.packer.write(obj).to_s
  rescue NoMethodError, RangeError
    # if the object included things that we can't serialize, fall back to
    # Marshal. It's a bit slower, but can encode anything yaml can.
    # NoMethodError is unexpected types; RangeError is Bignums
    return Marshal.dump(obj)
  end

  def storage_to_output(data)
    # This could have a meaning in messagepack, and we're being a little lazy
    # about it.
    if data[0] == 0x04.chr && data[1] == 0x08.chr
      Marshal.load(data)
    else
      msgpack_factory.unpacker.feed(data).read
    end
  end

  def input_to_output(data)
    block.call(data, path)
  end
end

class NativeFetchCache
  attr_accessor :handler, :cache_dir

  def initialize(cache_dir)
    self.cache_dir = cache_dir
  end

  # Fetch cached, processed contents from a file path.
  # fetch(path) {|contents| block } -> obj
  def fetch(path, &block)
    self.handler ||= NativeFetchHandler.new(&block)
    self.handler.path = path
    Bootsnap::CompileCache::Native.fetch(
      cache_dir,
      path.to_s,
      handler
    )
  rescue RuntimeError => e
    if e.message =~ /unmatched platform/
      puts "unmatched platform for file #{path}"
    end
    raise
  rescue Errno::ERANGE
    STDERR.puts <<~EOF
      \x1b[31mError loading xattr content from cache for \x1b[1;34m#{path}\x1b[0;31m!
      You can likely fix this by running:
        \x1b[1;32mxattr -c #{path}
      \x1b[0;31m...but, first, please make sure \x1b[1;34m@burke\x1b[0;31m knows you ran into this bug!
      He will want to see the results of:
        \x1b[1;32m/bin/ls -l@ #{path}
      \x1b[0;31mand:
        \x1b[1;32mxattr -p user.aotcc.key #{path}\x1b[0m
    EOF
    raise
  end
end