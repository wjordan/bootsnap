require 'test_helper'
require 'bootsnap/cache/xattr_cache'

class CompileCacheHandlerErrorsTest < Minitest::Test
  include TmpdirHelper

  def setup
    skip unless Bootsnap::CompileCache::ISeq.cache.is_a? XattrCache
    @prev_dir = Dir.pwd
    @tmp_dir = Dir.mktmpdir('aotcc-test')
    Dir.chdir(@tmp_dir)
    @handler = Bootsnap::CompileCache::ISeq.cache.handler
  end

  def teardown
    Dir.chdir(@prev_dir)
    FileUtils.remove_entry(@tmp_dir)
  end

  # now test three failure modes of each handler method:
  #   1. unexpected type
  #   2. invalid instance of expected type
  #   3. exception

  def test_input_to_storage_unexpected_type
    path = set_file('a.rb', 'a = 3', 100)
    @handler.expects(:input_to_storage).returns(nil)
    # this could be made slightly more obvious though.
    assert_raises(TypeError) { load(path) }
  end

  def test_input_to_storage_invalid_instance_of_expected_type
    path = set_file('a.rb', 'a = 3', 100)
    @handler.expects(:input_to_storage).returns('broken')
    @handler.expects(:input_to_output).with('a = 3').returns('whatever')
    _, err = capture_subprocess_io do
      load(path)
    end
    assert_match(/broken binary/, err)
  end

  def test_input_to_storage_raises
    path = set_file('a.rb', 'a = 3', 100)
    klass = Class.new(StandardError)
    @handler.expects(:input_to_storage).raises(klass, 'oops')
    assert_raises(klass) { load(path) }
  end

  def test_storage_to_output_unexpected_type
    path = set_file('a.rb', 'a = 3', 100)
    @handler.expects(:storage_to_output).returns(Object.new)
    # It seems like ruby doesn't really care.
    load(path)
  end

  # not really a thing. Really, we just return whatever. It's a problem with
  # the handler if that's invalid.
  # def test_storage_to_output_invalid_instance_of_expected_type

  def test_storage_to_output_raises
    path = set_file('a.rb', 'a = 3', 100)
    klass = Class.new(StandardError)
    @handler.expects(:storage_to_output).times(2).raises(klass, 'oops')
    assert_raises(klass) { load(path) }
    # called from two paths; this tests the second.
    assert_raises(klass) { load(path) }
  end

  def test_input_to_output_unexpected_type
    path = set_file('a.rb', 'a = 3', 100)
    @handler.expects(:input_to_storage).raises(Bootsnap::CompileCache::Uncompilable)
    @handler.expects(:input_to_output).returns(Object.new)
    # It seems like ruby doesn't really care.
    load(path)
  end

  # not really a thing. Really, we just return whatever. It's a problem with
  # the handler if that's invalid.
  # def test_input_to_output_invalid_instance_of_expected_type

  def test_input_to_output_raises
    path = set_file('a.rb', 'a = 3', 100)
    klass = Class.new(StandardError)
    @handler.expects(:input_to_storage).raises(Bootsnap::CompileCache::Uncompilable)
    @handler.expects(:input_to_output).raises(klass, 'oops')
    assert_raises(klass) { load(path) }
  end

  private

  def set_file(path, contents, mtime)
    File.write(path, contents)
    FileUtils.touch(path, mtime: mtime)
    path
  end
end
