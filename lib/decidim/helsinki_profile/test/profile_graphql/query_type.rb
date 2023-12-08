# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module ProfileGraphql
        # This type represents the root query type of the profile API.
        class QueryType < Decidim::Api::Types::BaseObject
          description "The root query of this schema"

          field_class AuthorizedField

          field :my_profile, ProfileNode, null: true do
            description "Get the profile belonging to the currently authenticated user."
          end

          def my_profile
            context[:current_profile]
          end
        end
      end
    end
  end
end
