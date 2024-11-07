# frozen_string_literal: true

require "spec_helper"

# The underlying OpenIDConnect stategy should already handle and test most of
# the OpenID connect specific functionality. The aim of this test is to test the
# Helsinki profile / Keycloak specific functionality within that strategy and
# the custom strategy methods. This should ensure our customizations and the
# basic flows also work when the underling strategy is changed.
describe OmniAuth::Strategies::Helsinki do # rubocop:disable RSpec/FilePath
  include Rack::Test::Methods
  include OmniAuth::Test::StrategyTestCase

  let(:decidim_host) { "service.org" }
  let(:oicd_config) do
    {
      issuer: "https://oicd.example.org/auth/realms/helsinki-tunnistus",
      authorization_endpoint: "https://oicd.example.org/auth/realms/helsinki-tunnistus/protocol/openid-connect/auth",
      token_endpoint: "https://oicd.example.org/auth/realms/helsinki-tunnistus/protocol/openid-connect/token",
      userinfo_endpoint: "https://oicd.example.org/auth/realms/helsinki-tunnistus/protocol/openid-connect/userinfo",
      end_session_endpoint: "https://oicd.example.org/auth/realms/helsinki-tunnistus/protocol/openid-connect/logout",
      introspection_endpoint: "https://oicd.example.org/auth/realms/helsinki-tunnistus/protocol/openid-connect/token/introspect",
      response_types_supported: ["code", "none", "id_token", "token", "id_token token", "code id_token", "code token", "code id_token token"],
      jwks_uri: "https://oicd.example.org/auth/realms/helsinki-tunnistus/protocol/openid-connect/certs",
      id_token_signing_alg_values_supported: %w(HS256 HS512 RS256 RS512),
      subject_types_supported: %w(public pairwise),
      token_endpoint_auth_methods_supported: %w(private_key_jwt client_secret_basic client_secret_post tls_client_auth client_secret_jwt)
    }
  end
  let(:strategy_options) do
    {
      issuer: oicd_config[:issuer],
      name: :helsinki,
      client_options: {
        port: 443,
        scheme: "https",
        host: "oicd.example.org",
        identifier: "auth-client",
        secret: "abcdef1234567890",
        redirect_uri: "http://#{decidim_host}/users/auth/helsinki/callback"
      },
      post_logout_redirect_uri: "http://#{decidim_host}/users/auth/helsinki/post_logout"
    }
  end
  let(:strategy) { [described_class, strategy_options] }

  around do |example|
    # Ensure that the strategy is running in "real" mode during the specs.
    OmniAuth.config.test_mode.tap do |prev_mode|
      OmniAuth.config.test_mode = false
      example.run
      OmniAuth.config.test_mode = prev_mode
    end
  end

  before do
    # Stub the openid configuration to return the locally stored metadata for
    # easier testing. Otherwise an external HTTP request would be made when the
    # OmniAuth strategy is configured AND there would need to be a Keycloak
    # authentication server always running at that URL.
    stub_request(
      :get,
      "#{oicd_config[:issuer]}/.well-known/openid-configuration"
    ).to_return(
      status: 200,
      body: oicd_config.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  describe "GET logout" do
    subject { response }

    let(:redirect_uri) { URI.parse(subject.location) }
    let(:logout_url) do
      redirect_uri.dup.tap do |uri|
        uri.query = nil
      end.to_s
    end
    let(:logout_params) { Rack::Utils.parse_query(redirect_uri.query).symbolize_keys! }

    context "when the id_token_hint is passed to the logout request" do
      let(:id_token) { "foobar" }
      let(:response) { get "/users/auth/helsinki/logout?id_token_hint=#{id_token}" }

      it "passes it forward to the authetication service" do
        expect(logout_url).to eq(oicd_config[:end_session_endpoint])
        expect(logout_params).to eq(
          id_token_hint: id_token,
          post_logout_redirect_uri: strategy_options[:post_logout_redirect_uri]
        )
      end
    end

    context "when the id_token_hint is not passed to the logout request" do
      let(:client_id) { strategy_options[:client_options][:identifier] }
      let(:response) { get "/users/auth/helsinki/logout" }

      it "passes the client_id parameter to the authentication service" do
        expect(logout_url).to eq(oicd_config[:end_session_endpoint])
        expect(logout_params).to eq(
          client_id: client_id,
          post_logout_redirect_uri: strategy_options[:post_logout_redirect_uri]
        )
      end
    end
  end
end
