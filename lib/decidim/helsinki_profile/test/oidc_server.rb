# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      class OidcServer
        class << self
          def get(key)
            return unless @servers

            @servers[key]
          end

          def register(key, uri)
            @servers ||= {}
            @servers[key] ||= new(uri)
          end
        end

        attr_reader :uri

        def initialize(uri)
          @uri = uri
        end

        def discovery
          OpenIDConnect::Discovery::Provider::Config::Response.new(
            issuer: uri,
            authorization_endpoint: "#{uri}/protocol/openid-connect/auth",
            token_endpoint: "#{uri}/protocol/openid-connect/token",
            userinfo_endpoint: "#{uri}/protocol/openid-connect/userinfo",
            jwks_uri: "#{uri}/protocol/openid-connect/certs",
            registration_endpoint: "#{uri}/clients-registrations/openid-connect",
            scopes_supported: %w(
              openid
              profile
              address
              microprofile-jwt
              add-amr-and-loa-claims
              add-ad-groups-claim
              phone
              acr
              offline_access
              email
              web-origins
              roles
            ),
            response_types_supported: [
              "code",
              "none",
              "id_token",
              "token",
              "id_token token",
              "code id_token",
              "code token",
              "code id_token token"
            ],
            grant_types_supported: %w(
              authorization_code
              implicit
              refresh_token
              password
              client_credentials
              urn:ietf:params:oauth:grant-type:device_code
              urn:openid:params:grant-type:ciba
            ),
            request_object_signing_alg_values_supported: [:PS384, :ES384, :RS384, :HS256, :HS512, :ES256, :RS256, :HS384, :ES512, :PS256, :PS512, :RS512, :none],
            subject_types_supported: %w(public pairwise),
            id_token_signing_alg_values_supported: [:PS384, :ES384, :RS384, :HS256, :HS512, :ES256, :RS256, :HS384, :ES512, :PS256, :PS512, :RS512],
            token_endpoint_auth_methods_supported: %w(private_key_jwt client_secret_basic client_secret_post tls_client_auth client_secret_jwt),
            claims_supported: %w(aud sub iss auth_time name given_name family_name preferred_username email acr)
          )
        end

        def jwk_rsa_keys
          @jwk_rsa_keys ||= [OpenSSL::PKey::RSA.new(2048), OpenSSL::PKey::RSA.new(2048)]
        end

        def jwks
          @jwks ||= JWT::JWK::Set.new(
            # Note that the algorithm is hard-coded here because it is not
            # automatically set by JWT::JWK.
            # https://github.com/jwt/ruby-jwt/blob/695143655b95d843d03d4a98ca43709cbe8169b4/lib/jwt/jwk/key_base.rb#L11-L22
            jwk_rsa_keys.map { |rsa| JWT::JWK.new(rsa, use: "sig", alg: "RS256") }
          )
        end

        def jwt(payload = {})
          issued_at = payload.delete(:iat) || Time.zone.now
          expires_at = payload.delete(:exp) || (issued_at + 30.minutes)
          scope = payload.delete(:scope) || Decidim::HelsinkiProfile.gdpr_scopes.values.join(" ")

          # Note that we use `JSON::JWT` instead of `JWT.encode` to better
          # control the signing of tokens.
          JSON::JWT.new(
            {
              exp: expires_at.to_i,
              iat: issued_at.to_i,
              jti: "96da3807-8ab9-4709-8c8f-e93f60dc7a96",
              iss: uri,
              aud: "profile-api-dev",
              sub: "60f03ffc-d02a-47b1-8315-395a37a9b4a0",
              azp: "exampleapp-ui-dev",
              session_state: "8a2cea63-4400-414d-8308-dcbe24d1482d",
              authorization: {
                permissions: [
                  {
                    scopes: ["access"]
                  }
                ]
              },
              scope: scope,
              sid: "8a2cea63-4400-414d-8308-dcbe24d1482d",
              amr: ["suomi_fi"],
              loa: "substantial"
            }.merge(payload)
          )
        end

        def token(payload = {})
          # We need to issue the same kid for the JSON::JWK key as the server keys
          # that are generated through JWT::JWK. We use JSON::JWK in the specs to
          # control better the signing of the keys.
          kid = JSON::JWK.new(jwk_rsa_keys.first, kid: jwks.first.kid)
          jwt = jwt(payload).sign(kid)

          expires_at = 30.minutes.from_now
          Rack::OAuth2::AccessToken::Bearer.new(
            access_token: jwt.to_s,
            expires_in: (expires_at - Time.now.utc).to_i
          )
        end

        def userinfo(data = nil)
          user_data = data || {
            name: "Fake Account",
            email: "fake@example.com",
            address: "Shibuya, Tokyo, Japan",
            profile: "http://example.org/fake",
            locale: "fi_FI",
            phone_number: "+358501234567",
            verified: false
          }
          OpenIDConnect::ResponseObject::UserInfo.new(user_data)
        end
      end
    end
  end
end
