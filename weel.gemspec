Gem::Specification.new do |s|
  s.name             = "weel"
  s.version          = "1.0.3"
  s.platform         = Gem::Platform::RUBY
  s.summary          = "preliminary release of the Workflow Execution Engine Library (WEEL)"

  s.description = <<-EOF
For WEE Library specific information see http://cpee.org/.

Copyright (C) 2008-2013 Jürgen Mangler <juergen.mangler@gmail.com> and others.

WEE Library is freely distributable according to the terms of the GNU Lesser General Public License (see the file 'COPYING').

This program is distributed without any warranty. See the file 'COPYING' for details.
EOF

  s.files            = Dir['{example/**/*,lib/*}'] + %w(COPYING FEATURES INSTALL Rakefile weel.gemspec README AUTHORS)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README']
  s.test_files       = Dir['{test/*,test/*/tc_*.rb}']

  s.authors          = ['Juergen eTM Mangler','Gerhard Stuermer']
  s.email            = 'juergen.mangler@gmail.com'
  s.homepage         = 'http://cpee.org'
end
