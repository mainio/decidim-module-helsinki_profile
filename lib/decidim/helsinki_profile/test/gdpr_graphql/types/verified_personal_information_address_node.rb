# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module GdprGraphql
        class VerifiedPersonalInformationAddressNode < Decidim::Api::Types::BaseObject
          graphql_name "VerifiedPersonalInformationAddressNode"

          field :street_address, GraphQL::Types::String, "Street address with possible house number etc.", null: false
          field :postal_code, GraphQL::Types::String, null: false
          field :post_office, GraphQL::Types::String, null: false
        end
      end
    end
  end
end
