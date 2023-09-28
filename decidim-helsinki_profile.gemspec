# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "decidim/helsinki_profile/version"

Gem::Specification.new do |spec|
  spec.name = "decidim-helsinki_profile"
  spec.version = Decidim::HelsinkiProfile.version
  spec.required_ruby_version = ">= 3.0"
  spec.authors = ["Antti Hukkanen"]
  spec.email = ["antti.hukkanen@mainiotech.fi"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.summary = "Provides possibility to bind Helsinki profile authentication provider to Decidim."
  spec.description = "Adds Helsinki profile authentication provider to Decidim."
  spec.homepage = "https://github.com/mainio/decidim-module-helsinki_profile"
  spec.license = "AGPL-3.0"

  spec.files = Dir[
    "{app,config,lib}/**/*",
    "LICENSE-AGPLv3.txt",
    "Rakefile",
    "README.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "decidim-core", Decidim::HelsinkiProfile.decidim_version
  spec.add_dependency "henkilotunnus", "~> 1.2.0"
  spec.add_dependency "jwt", "~> 2.7"
  spec.add_dependency "omniauth_openid_connect", "~> 0.7"
end
