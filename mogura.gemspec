# frozen_string_literal: true

require_relative "lib/mogura/version"

Gem::Specification.new do |spec|
  spec.name = "mogura"
  spec.version = Mogura::VERSION
  spec.authors = ["ysk"]
  spec.email = ["ysk.univ.1007@gmail.com"]

  spec.summary = "A mail filtering tool for IMAP."
  spec.description = "A mail filtering tool for IMAP."
  spec.homepage = "https://github.com/yskuniv/mogura"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  # TODO: setup around here in the future
  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  # spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "base64", "~> 0.2"
  spec.add_dependency "mail", "~> 2.8"
  spec.add_dependency "net-imap", "~> 0.5"
  spec.add_dependency "thor", "~> 1.3"
end
