# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      class Runtime
        def self.initialize
          Decidim::HelsinkiProfile::Test::OidcServer.register(
            :auth,
            "https://oicd.example.org/auth/realms/helsinki-tunnistus"
          )
          Decidim::HelsinkiProfile::Test::OidcServer.register(
            :gdpr,
            "https://gdpr.example.org/auth/decidim"
          )

          auth_server = Decidim::HelsinkiProfile::Test::OidcServer.get(:auth)
          gdpr_server = Decidim::HelsinkiProfile::Test::OidcServer.get(:gdpr)

          Rails.application.secrets.omniauth = {
            helsinki: {
              enabled: true,
              auth_uri: auth_server.uri,
              auth_client_id: "auth-client",
              auth_client_secret: "abcdef1234567890",
              gdpr_uri: gdpr_server.uri,
              gdpr_client_id: "profile-api-dev",
              gdpr_client_secret: "1234567890abcdef"
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