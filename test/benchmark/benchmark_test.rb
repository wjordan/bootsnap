require 'test_helper'
require 'benchmark/ips'

class BenchmarkTest < Minitest::Test
  include TmpdirHelper

  def setup
    @prev_dir = Dir.pwd
    @tmp_dir = Dir.mktmpdir('benchmark-test')
    Dir.chdir(@tmp_dir)
  end

  def teardown
    Dir.chdir(@prev_dir)
    FileUtils.remove_entry(@tmp_dir)
  end

  def test_benchmark
    path = set_file('a.rb', 'a = 3', 100)

    Benchmark.ips do |x|
      x.time = 10
      x.warmup = 2
      x.report("iseq_load") do
        load(path)
      end
    end
  end

  def set_file(path, contents, mtime)
    File.write(path, contents)
    FileUtils.touch(path, mtime: mtime)
    path
  end

end