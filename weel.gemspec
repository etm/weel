Gem::Specification.new do |s|
  s.name             = "weel"
  s.version          = "1.99.93"
  s.platform         = Gem::Platform::RUBY
  s.license          = "LGPL-3.0"
  s.summary          = "Workflow Execution Engine Library (WEEL)"

  s.description      = "see http://cpee.org"

  s.required_ruby_version = '>=2.5.0'

  s.files            = Dir['{example/**/*,lib/weel.rb}'] + %w(COPYING Changelog FEATURES INSTALL Rakefile weel.gemspec README.md AUTHORS)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README.md']
  s.test_files       = Dir['{test/*,test/*/tc_*.rb}']

  s.authors          = ['Juergen eTM Mangler','Gerhard Stuermer']
  s.email            = 'juergen.mangler@gmail.com'
  s.homepage         = 'http://cpee.org/'

  s.add_runtime_dependency 'test-unit',  '~> 3.0'
end
