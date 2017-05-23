require 'test_helper'
require 'bootsnap/cache/xattr_cache'

class CompileCacheKeyFormatTest < Minitest::Test
  include TmpdirHelper

  R = {
    version: 0..0,
    os_version: 1..1,
    compile_option: 2..5,
    data_size: 6..9,
    ruby_revision: 10..13,
    mtime: 14..21
  }

  def setup
    skip unless Bootsnap::CompileCache::ISeq.cache.is_a? XattrCache
    @prev_dir = Dir.pwd
    @tmp_dir = Dir.mktmpdir('aotcc-test')
    Dir.chdir(@tmp_dir)
  end

  def teardown
    Dir.chdir(@prev_dir)
    FileUtils.remove_entry(@tmp_dir)
  end

  def test_key_size
    key, = attrs_for_contents('a = 3')
    assert_equal(8 + 4 + 4 + 4 + 1 + 1, key.size)
  end

  def test_key_version
    key, = attrs_for_contents('a = 3')
    assert_equal(11.chr, key[R[:version]])
  end

  def test_key_compile_option_stable
    k1, = attrs_for_contents('a = 3')
    k2, = attrs_for_contents('a = 3')
    RubyVM::InstructionSequence.compile_option = { tailcall_optimization: true }
    k3, = attrs_for_contents('a = 3')
    assert_equal(k1[R[:compile_option]], k2[R[:compile_option]])
    refute_equal(k1[R[:compile_option]], k3[R[:compile_option]])
  ensure
    RubyVM::InstructionSequence.compile_option = { tailcall_optimization: false }
  end

  def test_key_ruby_revision
    key, = attrs_for_contents('a = 3')
    exp = [RUBY_REVISION].pack("L")
    assert_equal(exp, key[R[:ruby_revision]])
  end

  def test_key_data_size
    exp_size = begin
      path = File.expand_path('./12345.rb')
      File.write(path, 'a = 3')
      RubyVM::InstructionSequence.compile_file(path).to_binary.size
    end

    act_size = begin
      key, _ = attrs_for_contents('a = 3')
      key[R[:data_size]].unpack("L")[0]
    end

    assert_equal(exp_size, act_size)
  end

  def test_key_mtime
    key, = attrs_for_contents('a = 3')
    exp = Time.now.to_i
    act = key[R[:mtime]].unpack("Q")[0]
    assert_in_delta(exp, act, 1)
  end

  private

  def attrs_for_contents(contents)
    path = format("./%05d.rb", (rand * 100000).to_i)
    File.write(path, contents)
    require(path)
    key = get_attr("user.aotcc.key", path)
    cache = get_attr("user.aotcc.value", path)
    [key, cache, path]
  end

  def get_attr(name, path)
    xattr = Xattr.new(path)
    xattr[name]
  end

  def loadhex(str)
    [str.gsub(/\s/, '')].pack("H*")
  end
end
