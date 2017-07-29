require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rake/extensiontask'

task build: :compile

Rake::ExtensionTask.new('libdeflate_ext') do |ext|
  ext.ext_dir = 'ext/libdeflate'
  ext.lib_dir = 'lib/libdeflate'
end

task default: %i[clobber compile spec]
