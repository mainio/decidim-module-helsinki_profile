# frozen_string_literal: true

require "decidim/dev"

ENV["ENGINE_ROOT"] = File.dirname(__dir__)
ENV["NODE_ENV"] ||= "test"

# ENV["HELSINKIPROFILE_AUTH_URI"] = "https://auth.helsinkiprofile-test.fi"
# ENV["HELSINKIPROFILE_AUTH_CLIENT_ID"] = "client_id"
# ENV["HELSINKIPROFILE_AUTH_CLIENT_SECRET"] = "client_secret"

Decidim::Dev.dummy_app_path = File.expand_path(File.join(__dir__, "decidim_dummy_app"))

require "decidim/helsinki_profile/test/oidc_server"
require "decidim/helsinki_profile/test/gdpr_graphql"
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
    gdpr_api = Decidim::HelsinkiProfile::Test::GdprGraphql::Server.instance

    gdpr_api.reset_permissions
    gdpr_api.reset_profiles

    # Endpoints that are common for OICD servers
    discovery = auth_server.discovery

    # Respond to the metadata request with a stubbed request to avoid external
    # HTTP calls.
    stub_request(:get, "#{auth_server.uri}/.well-known/openid-configuration").to_return(
      headers: { "Content-Type" => "application/json" },
      body: discovery.to_json
    )

    stub_request(:get, discovery.jwks_uri).to_return(
      headers: { "Content-Type" => "application/json" },
      body: auth_server.jwks.export.to_json
    )

    # Endpoints needed only for the auth server
    discovery = auth_server.discovery

    stub_request(:post, discovery.token_endpoint).to_return do |request|
      if request.headers["Content-Type"] != "application/x-www-form-urlencoded"
        {
          status: 400,
          body: "Invalid request"
        }
      elsif (auth = request.headers["Authorization"]).present?
        # GDPR authentication request (i.e. already authenticated)
        form_data = URI.decode_www_form(request.body).to_h
        expected_data = {
          "audience" => Decidim::HelsinkiProfile.omniauth_secrets[:gdpr_client_id],
          "grant_type" => "urn:ietf:params:oauth:grant-type:uma-ticket",
          "permission" => "#access"
        }

        token = auth_server.api_tokens(auth) if expected_data == form_data
        if token
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: token.to_json
          }
        else
          {
            status: 400,
            body: "Invalid request"
          }
        end
      else
        form_data = URI.decode_www_form(request.body).to_h

        token_payload = {
          aud: Decidim::HelsinkiProfile.omniauth_secrets[:auth_client_id],
          scope: form_data["scope"]
        }
        token_payload[:sub] = token_sub if respond_to?(:token_sub) && token_sub

        {
          headers: { "Content-Type" => "application/json" },
          body: auth_server.token(token_payload).to_json
        }
      end
    end

    stub_request(:get, discovery.authorization_endpoint).to_return do |request|
      puts "AUTHORIZATION"
      puts request.inspect

      {
        status: 302,
        headers: { "Location" => "http://1.lvh.me/callback_uri" },
        body: ""
      }
    end

    stub_request(:get, discovery.userinfo_endpoint).to_return do |request|
      userinfo = auth_server.userinfo(request.headers["Authorization"])

      if userinfo
        {
          headers: { "Content-Type" => "application/json" },
          body: userinfo.to_json
        }
      else
        {
          status: 400,
          body: "Invalid request."
        }
      end
    end

    # Endpoints for the GDPR GraphQL API
    stub_request(:post, gdpr_api.uri).to_return do |request|
      gdpr_api.request(request)
    end
  end
end
