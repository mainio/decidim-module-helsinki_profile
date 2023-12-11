# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Oidc
      # Allows verifying OIDC tokens.
      class Connector
        attr_reader :id_token

        # Creates an OIDC connector object which can be used to communicate with
        # the given OIDC server.
        #
        # @param server_uri [String] The URI of the connected OIDC server
        # @param client_id [String] The client ID for the OIDC server
        # @param client_secret [String] The client secret for the OIDC server in
        #   case one of the algorithms HS256, HS384 or HS512 is used to sign the
        #   tokens at the server side
        def initialize(server_uri, client_id, client_secret = nil)
          @server_uri = server_uri
          @client_id = client_id
          @client_secret = client_secret
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

          authorized_scopes = scope.is_a?(Array) ? scope : scope.split(/\s+/)
          raise InvalidScopeError unless authorized_scopes.include?(requested_scope)
        end

        private

        attr_reader :server_uri, :client_id, :client_secret

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
            # Note that these alhorithms should not be normally needed with the
            # actual authentication server because the client secret is not
            # exposed to the end service (i.e. Decidim). We just have added the
            # support for these as well.
            jwt.verify!(client_secret)
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
        # given key.
        def discover!
          raise NotConfiguredError unless Decidim::HelsinkiProfile.configured?

          Decidim::HelsinkiProfile.discovery_request(server_uri) do
            OpenIDConnect::Discovery::Provider::Config.discover!(server_uri)
          end
        end
      end
    end
  end
end
