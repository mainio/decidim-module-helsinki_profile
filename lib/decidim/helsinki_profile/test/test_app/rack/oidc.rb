# frozen_string_literal: true

require "rack/oauth2"
require "openid_connect"

module Decidim
  module HelsinkiProfile
    module Test
      module TestApp
        module Rack
          class Oidc < App
            private

            def server_url(request)
              scheme = request.scheme
              scheme ||= "https" if request.port == 443
              scheme ||= "http"
              "#{scheme}://#{request.host}#{":#{request.port}" unless [80, 443].include?(request.port)}"
            end

            def issuer_url(request)
              "#{server_url(request)}#{base_path}"
            end

            def base_path
              @base_path ||= "/auth/realms/helsinki-tunnistus"
            end

            def serve(request)
              case request.path
              when "#{base_path}/.well-known/webfinger"
                webfinger_discovery(request)
              when "#{base_path}/.well-known/openid-configuration"
                openid_configuration(request)
              when "#{base_path}/protocol/openid-connect/certs"
                jwks(request)
              when "#{base_path}/protocol/openid-connect/auth"
                authorization(request)
              when "#{base_path}/protocol/openid-connect/logout"
                end_session(request)
              when "#{base_path}/protocol/openid-connect/token"
                token(request)
              when "#{base_path}/protocol/openid-connect/userinfo"
                userinfo(request)
              else
                not_found
              end
            end

            def webfinger_discovery(request)
              jrd = {
                links: [{
                  rel: OpenIDConnect::Discovery::Provider::Issuer::REL_VALUE,
                  href: issuer_url(request)
                }]
              }
              jrd[:subject] = request.params["resource"] if request.params["resource"].present?

              [200, { "Content-Type" => "application/jrd+json" }, [jrd.to_json]]
            end

            def openid_configuration(request)
              host_url = issuer_url(request)
              config = {
                issuer: host_url,
                authorization_endpoint: "#{host_url}/protocol/openid-connect/auth",
                jwks_uri: "#{host_url}/protocol/openid-connect/certs",
                response_types_supported: %w(code),
                subject_types_supported: %w(public),
                id_token_signing_alg_values_supported: %w(RS256),
                token_endpoint: "#{host_url}/protocol/openid-connect/token",
                userinfo_endpoint: "#{host_url}/protocol/openid-connect/userinfo",
                end_session_endpoint: "#{host_url}/protocol/openid-connect/logout",
                scopes_supported: %w(test),
                grant_types_supported: %w(authorization_code),
                token_endpoint_auth_methods_supported: %w(client_secret_basic client_secret_post),
                claims_supported: %w(sub iss name email)
              }

              [200, { "Content-Type" => "application/json" }, [config.to_json]]
            end

            def key_pair
              @key_pair ||= OpenSSL::PKey::RSA.generate(2048)
            end

            def jwks(request)
              return not_found unless request.request_method == "GET"

              [200, { "Content-Type" => "application/json" }, [jwk_set.to_json]]
            end

            def jwk_set
              @jwk_set ||= JSON::JWK::Set.new(JSON::JWK.new(key_pair.public_key))
            end

            def redirect_uri
              @redirect_uri ||= "http://localhost:3000/users/auth/helsinki/callback"
            end

            def post_logout_uri
              @post_logout_uri ||= "http://localhost:3000/users/auth/helsinki/post_logout"
            end

            def authorization(request)
              response_type = request.params["response_type"].to_s
              type_class =
                case response_type
                when "code"
                  ::Rack::OAuth2::Server::Authorize::Code
                when "token"
                  ::Rack::OAuth2::Server::Authorize::Token
                when ""
                  nil
                end
              return [400, {}, ["Invalid request."]] unless type_class

              type = type_class.new
              type._call(request.env)

              oauth_request = type.request
              oauth_response = type.response

              oauth_request.verify_redirect_uri!(redirect_uri)

              case request.request_method
              when "GET"
                keys = [:client_id, :response_type, :redirect_uri, :scope, :state, :nonce]
                html_body = <<~HTML.strip
                  <!DOCTYPE html>
                  <html lang="en">
                  <head>
                    <title>OIDC Dummy App</title>
                  </head>
                  <body>
                    <h1>Authorization request</h1>
                    <p>
                      This page represents an example OIDC server login page where the user would enter their SSO login
                      credentials to login with an external account. This is a very simple example implementation and
                      provides only a single user to test that the authentication flow works correctly with all its
                      parts.
                    </p>
                    <form action="#{base_path}/protocol/openid-connect/auth" method="post">
                      #{keys.map { |key| %(<input type="hidden" name="#{key}" value="#{oauth_request.send(key)}">) }.join("\n    ")}
                      <input name="commit" type="submit" value="approve">
                    </form>
                  </body>
                  </html>
                HTML

                [200, { "Content-Type" => "text/html; charset=UTF-8" }, [html_body]]
              when "POST"
                if request.params["commit"] == "approve"
                  oauth_response.code = "1234"
                  oauth_response.redirect_uri = redirect_uri
                  oauth_response.approve!
                  @nonce = request.params["nonce"]
                  [302, { "Location" => oauth_response.redirect_uri_with_credentials }, [""]]
                else
                  [403, {}, ["Access denied."]]
                end
              else
                not_found
              end
            end

            def nonce(request)
              request.params["nonce"]
            end

            def end_session(_request)
              @issued_access_token = nil

              [302, { "Location" => post_logout_uri }, [""]]
            end

            # rubocop:disable Metrics/CyclomaticComplexity
            def token(request)
              return not_found unless request.request_method == "POST"

              success_headers = {
                "Content-Type" => "application/json",
                "Cache-Control" => "no-store",
                "Pragma" => "no-cache"
              }

              case request.params["grant_type"]
              when "authorization_code"
                return token_error("invalid_client") unless request.params["client_id"] == "decidim_client"
                return token_error("invalid_client") unless request.params["client_secret"] == "decidim_secret"
                return token_error("invalid_client") unless request.params["redirect_uri"] == redirect_uri
                return token_error("invalid_grant") unless request.params["code"] == "1234"

                @issued_access_token = create_access_token(
                  iss: issuer_url(request),
                  nonce: @nonce,
                  azp: request.params["client_id"]
                )
                id_token = OpenIDConnect::ResponseObject::IdToken.new(
                  iss: issuer_url(request),
                  sub: @issued_access_token["sub"],
                  aud: request.params["client_id"],
                  nonce: @nonce,
                  exp: (Time.now.utc + 3600).to_i,
                  iat: Time.now.utc.to_i
                )
                response = {
                  access_token: @issued_access_token.to_s,
                  token_type: "bearer",
                  expires_in: 3600,
                  scope: @issued_access_token["scope"],
                  id_token: id_token.to_jwt(key_pair)
                }

                [200, success_headers, [response.to_json]]
              when "urn:ietf:params:oauth:grant-type:uma-ticket"
                token = decode_access_token(request)
                return token_error("invalid_client") unless token == @issued_access_token
                return token_error("invalid_grant") unless request.params["audience"] == "profile-api-dev"
                return token_error("invalid_grant") unless request.params["permission"] == "#access"

                access_token = create_access_token(
                  iss: issuer_url(request),
                  azp: request.params["audience"]
                )
                response = {
                  access_token: access_token.to_s,
                  token_type: "bearer",
                  expires_in: 3600,
                  scope: access_token["scope"]
                }

                [200, success_headers, [response.to_json]]
              else
                token_error("unsupported_grant_type")
              end
            end

            def token_error(key)
              description =
                case key
                when "invalid_client"
                  "Invalid client credentials."
                when "invalid_grant"
                  "Invalid grant."
                when "unsupported_grant_type"
                  "The access grant included - its type or another attribute - is not supported by the authorization server."
                else
                  "Invalid request."
                end

              error = {
                error: key,
                error_description: description
              }

              [401, { "Content-Type" => "application/json" }, [error.to_json]]
            end
            # rubocop:enable Metrics/CyclomaticComplexity

            def create_access_token(payload)
              JSON::JWT.new(
                {
                  exp: (Time.now.utc + 3600).to_i,
                  iat: Time.now.utc.to_i,
                  jti: SecureRandom.hex(32),
                  sub: "9e14df7c-81f6-4c41-8578-6aa7b9d0e5c0",
                  typ: "Bearer",
                  session_state: SecureRandom.hex(32),
                  scope: "openid email profile",
                  sid: SecureRandom.hex(32),
                  amr: ["suomi_fi"]
                }.merge(payload)
              )
            end

            def userinfo(request)
              return not_found unless request.request_method == "GET"
              return unauthorized unless @issued_access_token

              token = decode_access_token(request)
              return unauthorized unless token == @issued_access_token

              scopes = token["scope"].split

              userinfo = OpenIDConnect::ResponseObject::UserInfo.new
              userinfo.subject = "9e14df7c-81f6-4c41-8578-6aa7b9d0e5c0" if scopes.include?("openid")
              userinfo.name = "Heimo Helsinki" if scopes.include?("profile")
              if scopes.include?("email")
                userinfo.email = "openid@example.org"
                userinfo.email_verified = true
              end

              [200, { "Content-Type" => "application/json" }, [userinfo.to_json]]
            end

            def decode_access_token(request)
              auth_header = ::Rack::Auth::AbstractRequest.new(request.env)
              auth_token = auth_header.params if auth_header.provided? && !auth_header.parts.first.nil? && auth_header.scheme.to_s == "bearer"
              payload_token = request.params["access_token"]
              tokens = [auth_token, payload_token].compact
              return unless tokens.length == 1

              raw_token = tokens.first
              ::JSON::JWT.decode(raw_token, :skip_verification)
            end
          end
        end
      end
    end
  end
end
