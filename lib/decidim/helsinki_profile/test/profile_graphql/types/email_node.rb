# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module ProfileGraphql
        class EmailNode < Decidim::Api::Types::BaseObject
          graphql_name "EmailNode"

          field :id, GraphQL::Types::ID, null: false
          field :primary, GraphQL::Types::Boolean, null: false
          field :email, GraphQL::Types::String, null: false
          field :email_type, EmailType, null: true
          field :verified, GraphQL::Types::Boolean, null: false
        end
      end
    end
  end
end
