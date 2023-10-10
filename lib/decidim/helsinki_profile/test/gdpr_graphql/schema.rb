# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module GdprGraphql
        # Main GraphQL schema for decidim's API.
        class Schema < GraphQL::Schema
          mutation(MutationType)
          query(QueryType)

          default_max_page_size 50
          max_depth 50
          max_complexity 5000

          orphan_types(
            ProfileNode
          )

          def self.unauthorized_object(error)
            raise GraphQL::ExecutionError.new(
              "You do not have permission to perform this action.",
              extensions: { code: error_to_code(error) }
            )
          end

          def self.error_to_code(error)
            case error
            when GraphQL::UnauthorizedFieldError
              "PERMISSION_DENIED_ERROR"
            else
              "GENERAL_ERROR"
            end
          end
        end
      end
    end
  end
end
