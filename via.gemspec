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
  s.add_dependency "tty-prompt", ["~> 0.23.1"]
  s.add_dependency "tty-markdown", ["~> 0.7.2"]
  s.add_dependency "pastel", ["~> 0.8.0"]
  s.add_dependency "launchy", ["~> 2.5"]
  s.add_dependency "git", ["~> 1.19"]
  s.add_dependency "msgpack", ["~> 1.7"]
  s.add_dependency "httparty", ["~> 0.22.0"]
  s.add_dependency "event_stream_parser", ["~> 1.0"]
  s.add_dependency "markdown_stream_formatter", ["~> 1.0"]
end
