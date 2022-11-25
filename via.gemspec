Gem::Specification.new do |s|
  s.name = 'via'
  s.version = '1.0.0'
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = ">= 3.1.0"
  s.summary = 'ViaEurope cli toolkit'
  s.description = "ViaEurope cli toolkit'"
  s.authors = ['Philipp Schlesinger']
  s.email = ['info@philcomm.dev']
  s.homepage = ''
  s.license = 'MIT'
  s.files = Dir.glob('{lib,bin}/**/*')
  s.require_path = 'lib'
  s.executables = ['via']

  s.add_dependency "tty-option", ["~> 0.2"]
  s.add_dependency "launchy", ["~> 2.5"]
end
