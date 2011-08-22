Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_qiwi'
  s.version     = '0.50.2'
  s.summary     = 'Add qiwi paysystem for spree'
  s.description = 'Add qiwi paysystem for spree'
  s.required_ruby_version = '>= 1.8.7'

  s.author            = 'Pronix LLC'
  s.email             = 'pronix.service@gmail.com'
  s.homepage          = 'http://tradefast.ru'
  # s.rubyforge_project = 'actionmailer'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency('nokogiri')
  s.add_dependency('spree_core', '>= 0.50.2')
end
