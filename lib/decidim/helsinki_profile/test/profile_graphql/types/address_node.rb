# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module ProfileGraphql
        class AddressNode < Decidim::Api::Types::BaseObject
          graphql_name "AddressNode"

          field :id, GraphQL::Types::ID, null: false
          field :primary, GraphQL::Types::Boolean, null: false
          field :address, GraphQL::Types::String, null: false
          field :postal_code, GraphQL::Types::String, null: false
          field :city, GraphQL::Types::String, null: false
          field :country_code, GraphQL::Types::String, null: false
          field :address_type, AddressType, null: true
        end
      end
    end
  end
end
