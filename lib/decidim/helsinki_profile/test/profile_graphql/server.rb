# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module ProfileGraphql
        class Server
          include Singleton

          def uri
            @uri ||= "https://profile-api.example.org/graphql/"
          end

          def request(req)
            authorization = req.headers["Authorization"]
            current_profile = authenticate(authorization)
            raise "Invalid request Content-Type, expected: application/json" if req.headers["Content-Type"] != "application/json"

            body = JSON.parse(req.body)
            raise "Request body does not contain a query" if body["query"].blank?

            result = execute(body["query"], current_profile: current_profile)

            {
              status: 200,
              body: result.to_json
            }
          end

          def execute(query, variables: {}, operation_name: nil, current_profile: nil)
            context = { current_profile: current_profile, permissions: permissions }

            Schema.execute(query, variables: variables, operation_name: operation_name, context: context)
          end

          def authenticate(authorization)
            return if authorization.blank?

            token = oidc.authorize_header!(authorization)
            oidc.validate_scope!("gdprquery")

            profile(token.sub)
          rescue Decidim::HelsinkiProfile::Oidc::InvalidTokenError, Decidim::HelsinkiProfile::Oidc::InvalidScopeError
            nil
          end

          def reset_permissions
            @permissions = default_permissions
          end

          def set_permission(key, value)
            permissions[key] = value
          end

          def reset_profiles
            @profiles = {}
          end

          def register_profile(data)
            @profiles ||= {}

            @profiles[data[:id]] = data
          end

          def profile(uuid)
            return unless @profiles

            @profiles[uuid]
          end

          private

          def permissions
            @permissions ||= default_permissions

            @permissions
          end

          def default_permissions
            { verified_information: true }
          end

          def oidc
            @oidc ||= Decidim::HelsinkiProfile::Oidc::Connector.new(:auth)
          end
        end
      end
    end
  end
end
