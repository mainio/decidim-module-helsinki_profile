# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module GdprGraphql
        class Server
          include Singleton

          def uri
            @uri ||= "https://gdpr-api.example.org/graphql/"
          end

          def request(req)
            authorization = req.headers["Authorization"]
            current_profile = authenticate(authorization)
            result = execute(req.body, current_profile: current_profile)

            {
              status: 200,
              body: result.to_json
            }
          end

          def execute(query, variables: {}, operation_name: nil, current_profile: nil)
            context = { current_profile: current_profile }

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

          def oidc
            @oidc ||= Decidim::HelsinkiProfile::Oidc::Connector.new(:auth)
          end
        end
      end
    end
  end
end
