# encoding: utf-8

require 'bundler'
begin
  Bundler.setup(:default, :development, :debug, :test)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

$:.unshift(File.join(File.dirname(__FILE__), './lib'))
require 'namae'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  gem.name = 'namae'
  gem.version = Namae::Version::STRING.dup
  gem.homepage = 'https://github.com/berkmancenter/namae'

  gem.email = ['sylvester@keil.or.at', 'dan@collispuro.com']
  gem.authors = ['Sylvester Keil', 'Dan Collis-Puro']

  gem.license = 'AGPL'

  gem.summary =
    'Namae parses personal names and splits them into their component parts.'

  gem.description = %q{
    Namae is a parser for human names. It recognizes personal names of various
    cultural backgrounds and tries to split them into their component parts
    (e.g., given and family names, honorifics etc.).
  }.gsub(/\s+/, ' ')

end
Jeweler::RubygemsDotOrgTasks.new

desc 'Generate the name parser'
task :racc => ['lib/namae/parser.rb']

file 'lib/namae/parser.rb' => ['lib/namae/parser.y'] do
  sh 'bundle exec racc -o lib/namae/parser.rb lib/namae/parser.y'
end

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

require 'cucumber/rake/task'
Cucumber::Rake::Task.new(:features)

task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new
