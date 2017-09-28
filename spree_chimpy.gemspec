# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_chimpy'
  s.version     = '3.3.0'
  s.summary     = 'MailChimp/Spree integration using the mailchimp gem'
  s.description = s.summary
  s.required_ruby_version = '>= 1.9.3'

  s.author    = 'Joshua Nussbaum'
  s.email     = 'josh@godynamo.com'
  s.homepage  = 'http://github.com/spree-contrib/spree_chimpy'
  s.license   = %q{BSD-3}

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', '>= 3.1.0', '< 4.0'
  s.add_dependency 'spree_extension'
  s.add_dependency 'gibbon', '~> 3.0'

  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'poltergeist'
  s.add_development_dependency 'factory_girl'
  s.add_development_dependency 'shoulda-matchers'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'coffee-rails'
  s.add_development_dependency 'sass-rails'
  s.add_development_dependency 'ffaker'
  s.add_development_dependency 'launchy'
  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'mysql2'
end
