# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Oidc
      # Allows verifying OIDC tokens.
      class Connector
        attr_reader :id_token

        # Creates an OIDC connector object which can be used to communicate with
        # the given OIDC server (either :auth or :gdpr).
        #
        # @param key [String] The key of the connected service, either :auth or
        #   :gdpr
        def initialize(server)
          @server = server
        end

        def authorize_header!(header, **kwargs)
          raise InvalidTokenError if header.blank?

          match = header.match(/Bearer\s+(.+)/)
          raise InvalidTokenError unless match

          authorize!(match[1], **kwargs)
        end

        # See:
        # https://profile-api.dev.hel.ninja/docs/gdpr-api/
        def authorize!(raw_token, nonce: nil, sub: nil)
          @id_token = decode_token(raw_token)

          raise InvalidTokenError unless id_token

          client_id = Decidim::HelsinkiProfile.omniauth_secrets["#{server}_client_id".to_sym]
          id_token.verify!(
            issuer: config.issuer,
            audience: client_id,
            nonce: nonce.presence
          )

          raise InvalidTokenError if sub.present? && id_token.sub != sub

          id_token
        rescue OpenIDConnect::ResponseObject::IdToken::InvalidToken
          raise InvalidTokenError
        end

        # See:
        # https://profile-api.dev.hel.ninja/docs/gdpr-api/
        def validate_scope!(requested_scope)
          raise InvalidTokenError unless id_token

          scope = id_token.raw_attributes[:scope]
          raise InvalidScopeError if scope.blank?

          authorized_scopes = scope.split(/\s+/)
          raise InvalidScopeError unless authorized_scopes.include?(requested_scope)
        end

        private

        attr_reader :server

        # Decode the token from the authorization header and verify it against
        # the key identified by the "kid" as supplied with the JWT or when no
        # "kid" is supplied, with any potential key. If the signing
        # algorithm is one of "HS256", "HS384" or "HS512", verify the key
        # against the secret.
        def decode_token(raw_token)
          # The token is verified below but we need the token data to detect
          # how we should verify it.
          jwt = JSON::JWT.decode(raw_token, :skip_verification)

          case jwt.algorithm.to_sym
          when :HS256, :HS384, :HS512
            secret = Decidim::HelsinkiProfile.omniauth_secrets["#{server}_client_secret".to_sym]
            jwt.verify!(secret)
            return ::OpenIDConnect::ResponseObject::IdToken.new(jwt)
          else
            if jwt.kid
              jwt.verify!(config.jwk(jwt.kid))
              return ::OpenIDConnect::ResponseObject::IdToken.new(jwt)
            else
              signature_keys = config.jwks.select { |k| k["use"] == "sig" && k["alg"] == jwt.alg }
              signature_keys.each do |key|
                token = ::OpenIDConnect::ResponseObject::IdToken.decode(raw_token, key)
                return token if token
              end
            end
          end

          raise InvalidTokenError
        rescue JSON::JWT::InvalidFormat, JSON::JWK::Set::KidNotFound, JSON::JWS::VerificationFailed, JSON::JWS::UnexpectedAlgorithm, JSON::JWK::UnknownAlgorithm
          raise InvalidTokenError
        end

        def config
          @config ||= discover!
        end

        # Fetches the OIDC configuration from the authentication server for the
        # given key (either :auth or :gdpr).
        def discover!
          raise NotConfiguredError unless Decidim::HelsinkiProfile.configured?

          server_uri = Decidim::HelsinkiProfile.omniauth_secrets["#{server}_uri".to_sym]
          Decidim::HelsinkiProfile.discovery_request(server_uri) do
            OpenIDConnect::Discovery::Provider::Config.discover!(server_uri)
          end
        end
      end
    end
  end
end
