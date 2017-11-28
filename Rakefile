require 'rake'
require 'rubygems/package_task'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['./test/*/tc_*.rb']
  t.verbose = false
end

spec = eval(File.read('weel.gemspec'))
Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
  `rm pkg/* -rf`
  `ln -sf #{pkg.name}.gem pkg/weel.gem`
end

task :push => :gem do |r|
  `gem push pkg/weel.gem`
end

task :install => :gem do |r|
  `gem install pkg/weel.gem`
end
