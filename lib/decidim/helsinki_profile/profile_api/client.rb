# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module ProfileApi
      # Allows fetching data from the profile API towards Decidim. This is
      # needed because the OIDC response does not necessarily contain all the
      # data that is needed for the user authorizations which are needed for
      # voting.
      class Client
        # The access token is the token provided by the authorization server
        # (Keycloak). This token is used to fetch a "backend" token for the
        # backend app to manage the user's data through the profile API. Once
        # the token is issued, it can be used to fetch further user details
        # through the profile API using this client.
        def initialize(access_token)
          @access_token = access_token
        end

        def authenticate!
          return @auth_tokens if @auth_tokens

          form_data = {
            "audience" => token_audience,
            "grant_type" => token_grant_type,
            "permission" => token_permission
          }

          http = Net::HTTP.new(auth_token_uri.host, auth_token_uri.port)
          http.use_ssl = auth_token_uri.scheme == "https"
          response = nil
          http.start do
            request = Net::HTTP::Post.new(auth_token_uri.request_uri)
            request["Authorization"] = "Bearer #{access_token}"
            request.set_form_data(form_data.compact)

            response = http.request(request)
          end

          raise AuthenticationError unless response
          raise AuthenticationError if response.code != "200"

          token_data = JSON.parse(response.body)

          @auth_tokens =
            if token_data["access_token"].present?
              { token_audience => token_data["access_token"] }
            else
              token_data
            end
        rescue JSON::ParserError
          raise AuthenticationError
        end

        def fetch
          authenticate!

          query = %(
            myProfile {
              firstName
              lastName
              nickname
              primaryEmail { email verified }
              verifiedPersonalInformation {
                firstName
                givenName
                lastName
                nationalIdentificationNumber
                municipalityOfResidenceNumber
                permanentAddress { postalCode }
              }
            }
          )

          response = Net::HTTP.post(
            profile_api_uri,
            { query: "{ #{query} }" }.to_json,
            "Authorization" => "Bearer #{auth_tokens[token_audience]}",
            "Content-Type" => "application/json"
          )
          raise QueryError, "Invalid response code from profile API: #{response.code}" if response.code != "200"

          json = JSON.parse(response.body)
          check_errors!(json)

          profile = json["data"]["myProfile"]
          raise QueryError, "Empty profile information from profile API." if profile.blank?

          profile.deep_transform_keys { |key| key.underscore.to_sym }
        rescue JSON::ParserError
          raise QueryError, "Invalid response body from profile API."
        end

        private

        attr_reader :access_token, :auth_tokens

        def check_errors!(json)
          return if json["errors"].blank?

          raise QueryError, json["errors"].map { |err| err["message"] }.join(", ")
        end

        def token_audience
          Decidim::HelsinkiProfile.omniauth_secrets[:profile_api_client_id]
        end

        def token_grant_type
          "urn:ietf:params:oauth:grant-type:uma-ticket"
        end

        def token_permission
          "#access"
        end

        def profile_api_uri
          @profile_api_uri ||= URI.parse(Decidim::HelsinkiProfile.omniauth_secrets[:profile_api_uri])
        end

        def auth_token_uri
          @auth_token_uri ||=
            URI.parse("#{Decidim::HelsinkiProfile.omniauth_secrets[:auth_uri]}/protocol/openid-connect/token")
        end
      end
    end
  end
end
