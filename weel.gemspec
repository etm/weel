Gem::Specification.new do |s|
  s.name             = "weel"
  s.version          = "1.99.24"
  s.platform         = Gem::Platform::RUBY
  s.license          = "LGPL-3"
  s.summary          = "Preliminary release of the Workflow Execution Engine Library (WEEL)"

  s.description      = "see http://cpee.org"

  s.required_ruby_version = '>=1.9.3'

  s.files            = Dir['{example/**/*,lib/weel.rb}'] + %w(COPYING Changelog FEATURES INSTALL Rakefile weel.gemspec README AUTHORS)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README']
  s.test_files       = Dir['{test/*,test/*/tc_*.rb}']

  s.authors          = ['Juergen eTM Mangler','Gerhard Stuermer']
  s.email            = 'juergen.mangler@gmail.com'
  s.homepage         = 'http://cpee.org/'
end
