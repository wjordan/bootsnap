$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'minitest/reporters'
Minitest::Reporters.use!(
  Minitest::Reporters::SpecReporter.new
)

require 'bundler/setup'
require 'bootsnap'

require 'tmpdir'
require 'fileutils'
require 'ffi-xattr'

require 'minitest/autorun'
require 'mocha/mini_test'

Bootsnap.setup(
  cache_dir: Dir.mktmpdir('compile-cache'),
  load_path_cache: false,
  autoload_paths_cache: false
)

module NullCache
  def self.get(*)
  end

  def self.set(*)
  end

  def self.transaction(*)
    yield
  end

  def self.fetch(*)
    yield
  end
end

module TmpdirHelper
  def setup
    super
    @prev_dir = Dir.pwd
    @tmp_dir = Dir.mktmpdir('aotcc-test')
    Dir.chdir(@tmp_dir)
  end

  def teardown
    super
    Dir.chdir(@prev_dir)
    FileUtils.remove_entry(@tmp_dir)
  end
end
