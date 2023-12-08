# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      class Runtime
        def self.initialize
          # When running the rake tasks for the test app, e.g. migrations, this
          # would fail because they are not using the spec helper that requires
          # the test dependencies.
          return unless defined?(Decidim::HelsinkiProfile::Test::OidcServer)

          Decidim::HelsinkiProfile::Test::OidcServer.register(
            :auth,
            "https://oicd.example.org/auth/realms/helsinki-tunnistus",
            "auth-client"
          )

          auth_server = Decidim::HelsinkiProfile::Test::OidcServer.get(:auth)
          profile_api = Decidim::HelsinkiProfile::Test::ProfileGraphql::Server.instance

          Rails.application.secrets.omniauth = {
            helsinki: {
              enabled: true,
              auth_uri: auth_server.uri,
              auth_client_id: "auth-client",
              auth_client_secret: "abcdef1234567890",
              gdpr_client_id: "gdpr-client-id",
              profile_api_uri: profile_api.uri,
              profile_api_client_id: "profile-api-dev"
            }
          }

          # Add the test templates path to ActionMailer
          ActionMailer::Base.prepend_view_path(
            File.expand_path(File.join(__dir__, "../../../../spec/fixtures", "mailer_templates"))
          )
        end
      end
    end
  end
end
