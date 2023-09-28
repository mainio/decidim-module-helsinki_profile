# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Oidc
      autoload :Connector, "decidim/helsinki_profile/oidc/connector"

      class OidcError < StandardError; end

      class NotConfiguredError < OidcError; end

      class InvalidTokenError < OidcError; end

      class InvalidScopeError < OidcError; end
    end
  end
end
