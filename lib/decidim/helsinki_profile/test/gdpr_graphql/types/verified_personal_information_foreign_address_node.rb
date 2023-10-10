# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module GdprGraphql
        class VerifiedPersonalInformationForeignAddressNode < Decidim::Api::Types::BaseObject
          graphql_name "VerifiedPersonalInformationForeignAddressNode"

          field :street_address, GraphQL::Types::String, "Street address or whatever is the first part of the address.", null: false
          field :additional_address, GraphQL::Types::String, "Additional address information, perhaps town, county, state, country etc.", null: false
          field :country_code, GraphQL::Types::String, "An ISO 3166-1 country code.", null: false
        end
      end
    end
  end
end
