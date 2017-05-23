require 'test_helper'
require 'bootsnap/cache/xattr_cache'

class CompileCacheTest < Minitest::Test
  include TmpdirHelper

  def setup
    skip unless Bootsnap::CompileCache::ISeq.cache.is_a? XattrCache
    ENV.delete('OPT_AOT_LOG')
    super
  end

  def test_no_write_permission
    path = set_file('a.rb', 'a = 3', 100)
    FileUtils.chmod(0400, path)
    XattrHandler.expects(:input_to_storage).never
    XattrHandler.expects(:input_to_output).times(2).returns('whatever')
    ENV['OPT_AOT_LOG'] = '1'
    _, err = capture_subprocess_io do
      load(path)
      load(path)
    end
    assert_match(/no write perm.*no write perm/m, err)
  end

  def test_no_write_permission_without_logging
    path = set_file('a.rb', 'a = 3', 100)
    FileUtils.chmod(0400, 'a.rb')
    XattrHandler.expects(:input_to_storage).never
    XattrHandler.expects(:input_to_output).times(2).returns('whatever')
    ENV['OPT_AOT_LOG'] = '0'
    _, err = capture_subprocess_io do
      load(path)
      load(path)
    end
    assert_empty(err)
  end

  def test_file_is_only_read_once
    path = set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    # This doesn't really *prove* the file is only read once, but
    # it at least asserts the input is only cached once.
    XattrHandler.expects(:input_to_storage).times(1).returns(storage)
    XattrHandler.expects(:storage_to_output).times(2).returns(output)
    load(path)
    load(path)
  end

  def test_raises_syntax_error
    path = set_file('a.rb', 'a = (3', 100)
    assert_raises(SyntaxError) do
      # SyntaxError emits directly to stderr in addition to raising, it seems.
      capture_subprocess_io { load(path) }
    end
  end

  def test_no_recache_when_mtime_same
    path = set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    XattrHandler.expects(:input_to_storage).times(1).returns(storage)
    XattrHandler.expects(:storage_to_output).times(2).returns(output)

    load(path)
    set_file(path, 'not the same', 100)
    load(path)
  end

  def test_recache
    path = set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    # Totally lies the second time but that's not the point.
    XattrHandler.expects(:input_to_storage).times(2).returns(storage)
    XattrHandler.expects(:storage_to_output).times(2).returns(output)

    load(path)
    set_file(path, 'a = 2', 101)
    load(path)
  end

  def test_missing_cache_data
    path = set_file('a.rb', 'a = 3', 100)
    storage = RubyVM::InstructionSequence.compile_file(path).to_binary
    output = RubyVM::InstructionSequence.load_from_binary(storage)
    XattrHandler.expects(:input_to_storage).times(2).returns(storage)
    XattrHandler.expects(:storage_to_output).times(2).returns(output)
    load(path)
    xattr = Xattr.new(path)
    xattr.remove('user.aotcc.value')
    load(path)
  end

  private

  def set_file(path, contents, mtime)
    File.write(path, contents)
    FileUtils.touch(path, mtime: mtime)
    path
  end
end
