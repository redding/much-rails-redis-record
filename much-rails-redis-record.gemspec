# -*- encoding: utf-8 -*-
# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "much-rails-redis-record/version"

Gem::Specification.new do |gem|
  gem.name        = "much-rails-redis-record"
  gem.version     = MuchRailsRedisRecord::VERSION
  gem.authors     = ["Kelly Redding", "Collin Redding"]
  gem.email       = ["kelly@kellyredding.com", "collin.redding@me.com"]
  gem.summary     = "Store records in Redis with MuchRails."
  gem.description = "Store records in Redis with MuchRails."
  gem.homepage    = "https://github.com/redding/much-rails-redis-record"
  gem.license     = "MIT"

  gem.files = `git ls-files | grep "^[^.]"`.split($INPUT_RECORD_SEPARATOR)

  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.required_ruby_version = "~> 2.5"

  gem.add_development_dependency("much-style-guide", ["~> 0.6.4"])
  gem.add_development_dependency("assert",           ["~> 2.19.6"])

  gem.add_dependency("hella-redis", ["~> 0.5.0"])
end
