# frozen_string_literal: true

require "graphql"
require "decidim/api/types"
require "decidim/helsinki_profile/test/profile_graphql"

module Decidim
  module HelsinkiProfile
    module Test
      module TestApp
        module Rack
          class Graphql < App
            private

            def serve(request)
              return not_found unless request.path == "/graphql/"
              return [200, {}, ["GraphQL API responding to POST requests."]] unless request.request_method == "POST"
              return [422, {}, ["Cannot process other than application/json type requests."]] unless request.headers["Content-Type"] == "application/json"
              return unauthorized unless authorized?(request)

              body = JSON.parse(request.body.string)

              context = {
                current_profile: profile_data,
                permissions: { verified_information: true }
              }
              result = Decidim::HelsinkiProfile::Test::ProfileGraphql::Schema.execute(
                body["query"],
                context: context,
                variables: {},
                operation_name: nil
              )

              [200, { "Content-Type" => "application/json" }, [result.to_json]]
            rescue JSON::ParserError
              [422, {}, ["Invalid JSON within the request body."]]
            end

            # Note that this does not validate that the access token originates
            # from the issuing server because this is only used for testing
            # purposes.
            def authorized?(request)
              raw_token = request.headers["Authorization"]
              match = raw_token.match(/^Bearer\s+(.*)/)
              return false unless match

              begin
                token = ::JSON::JWT.decode(match[1], :skip_verification)
              rescue JSON::JWT::InvalidFormat
                return false
              end

              oidc_port = ENV.fetch("HELSINKI_PROFILE_OIDC_PORT", 8080)
              return false unless token["iss"] == "http://localhost:#{oidc_port}/auth/realms/helsinki-tunnistus"
              return false unless token["sub"] == "9e14df7c-81f6-4c41-8578-6aa7b9d0e5c0"
              return false if token["exp"] < Time.now.utc.to_i

              scopes = token["scope"].split
              return false unless scopes.include?("profile")

              true
            end

            def profile_data
              {
                id: "00000000-1111-2222-3333-aaaaaaaaaaaa",
                firstName: "Heimo",
                lastName: "Helsinki",
                nickname: "heimohelsinki",
                language: "fi",
                primaryEmail: {
                  id: "aaaaaaaa-bbbb-cccc-dddd-111111111111",
                  primary: true,
                  email: "heimohelsinki@example.org",
                  emailType: "PERSONAL",
                  verified: true
                },
                primaryAddress: {
                  id: "aaaaaaaa-bbbb-cccc-dddd-222222222222",
                  primary: true,
                  address: "Veneentekijäntie 4 A",
                  postalCode: "00210",
                  city: "Helsinki",
                  countryCode: "FI",
                  addressType: "WORK"
                },
                verifiedPersonalInformation: {
                  firstName: "Heimo",
                  lastName: "Helsinki",
                  givenName: "Heimo",
                  # Note that the national ID number is a "test" number (unique
                  # numbers above 900 after the separator) and generated
                  # programmatically.
                  nationalIdentificationNumber: "070595-987W",
                  municipalityOfResidence: "Helsinki",
                  municipalityOfResidenceNumber: "091",
                  permanentAddress: {
                    id: "aaaaaaaa-bbbb-cccc-dddd-333333333333",
                    primary: true,
                    address: "Veneentekijäntie 1",
                    postalCode: "00210",
                    city: "Helsinki",
                    countryCode: "FI",
                    addressType: "HOME"
                  },
                  temporaryAddress: nil,
                  permanentForeignAddress: nil
                }
              }
            end
          end
        end
      end
    end
  end
end
