# frozen_string_literal: true

require "decidim/dev"

ENV["ENGINE_ROOT"] = File.dirname(__dir__)
ENV["NODE_ENV"] ||= "test"

# ENV["HELSINKIPROFILE_AUTH_URI"] = "https://auth.helsinkiprofile-test.fi"
# ENV["HELSINKIPROFILE_AUTH_CLIENT_ID"] = "client_id"
# ENV["HELSINKIPROFILE_AUTH_CLIENT_SECRET"] = "client_secret"

Decidim::Dev.dummy_app_path = File.expand_path(File.join(__dir__, "decidim_dummy_app"))

require "decidim/helsinki_profile/test/oidc_server"
require "decidim/dev/test/base_spec_helper"

RSpec.configure do |config|
  # Make it possible to sign in and sign out the user in the request type specs.
  # This is needed because we need the request type spec for the omniauth
  # callback tests.
  config.include Devise::Test::IntegrationHelpers, type: :request

  config.before(:all) do
    # Silence the OmniAuth logger
    OmniAuth.config.request_validation_phase = proc {}
    OmniAuth.config.logger = Logger.new("/dev/null")

    # Configure the HelsinkiProfile module
    Decidim::HelsinkiProfile.configure do |hpconfig|
      hpconfig.auto_email_domain = "1.lvh.me"
    end

    # Re-define the password validators due to a bug in the "email included"
    # check which does not work well for domains such as "1.lvh.me" that we are
    # using during tests.
    PasswordValidator.send(:remove_const, :VALIDATION_METHODS)
    PasswordValidator.const_set(
      :VALIDATION_METHODS,
      [
        :password_too_short?,
        :password_too_long?,
        :not_enough_unique_characters?,
        :name_included_in_password?,
        :nickname_included_in_password?,
        # :email_included_in_password?,
        :domain_included_in_password?,
        :password_too_common?,
        :blacklisted?
      ].freeze
    )
  end

  config.before do
    auth_server = Decidim::HelsinkiProfile::Test::OidcServer.get(:auth)
    gdpr_server = Decidim::HelsinkiProfile::Test::OidcServer.get(:gdpr)

    [auth_server, gdpr_server].each do |server|
      discovery = server.discovery

      # Respond to the metadata request with a stubbed request to avoid external
      # HTTP calls.
      stub_request(:get, "#{server.uri}/.well-known/openid-configuration").to_return(
        headers: { "Content-Type" => "application/json" },
        body: discovery.to_json
      )

      stub_request(:get, discovery.jwks_uri).to_return(
        headers: { "Content-Type" => "application/json" },
        body: server.jwks.export.to_json
      )
    end

    # Endpoints needed only for the auth server
    discovery = auth_server.discovery

    stub_request(:post, discovery.token_endpoint).to_return(
      headers: { "Content-Type" => "application/json" },
      body: auth_server.token.to_json
    )

    stub_request(:get, discovery.authorization_endpoint).to_return do
      {
        status: 302,
        headers: { "Location" => "http://1.lvh.me/callback_uri" },
        body: ""
      }
    end

    stub_request(:get, discovery.userinfo_endpoint).to_return(
      headers: { "Content-Type" => "application/json" },
      body: auth_server.userinfo.to_json
    )
  end
end
