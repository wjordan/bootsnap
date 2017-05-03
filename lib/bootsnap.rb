require_relative 'bootsnap/version'
require_relative 'bootsnap/load_path_cache'
require_relative 'bootsnap/compile_cache'
require_relative 'bootsnap/cache_wrapper'

module Bootsnap
  InvalidConfiguration = Class.new(StandardError)

  def self.setup(
    cache_dir: nil,
    development_mode: true,
    load_path_cache: true,
    autoload_paths_cache: true,
    disable_trace: false,
    compile_cache_iseq: true,
    compile_cache_yaml: true
  )
    load_path_cache = CacheWrapper.get(load_path_cache)
    if load_path_cache.nil? && cache_dir
      require_relative 'bootsnap/load_path_cache/store'
      load_path_cache = Bootsnap::LoadPathCache::Store.new(cache_dir)
    end

    compile_cache_iseq = CacheWrapper.get(compile_cache_iseq) || compile_cache_iseq
    compile_cache_yaml = CacheWrapper.get(compile_cache_yaml) || compile_cache_yaml

    if autoload_paths_cache && !load_path_cache
      raise InvalidConfiguration, "feature 'autoload_paths_cache' depends on feature 'load_path_cache'"
    end

    setup_disable_trace if disable_trace

    Bootsnap::LoadPathCache.setup(
      cache:            load_path_cache,
      development_mode: development_mode,
      active_support:   autoload_paths_cache
    ) if load_path_cache

    Bootsnap::CompileCache.setup(
      iseq: compile_cache_iseq,
      yaml: compile_cache_yaml
    )
  end

  def self.setup_disable_trace
    RubyVM::InstructionSequence.compile_option = { trace_instruction: false }
  end
end
