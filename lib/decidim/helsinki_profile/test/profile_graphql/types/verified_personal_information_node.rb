# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module ProfileGraphql
        class VerifiedPersonalInformationNode < Decidim::Api::Types::BaseObject
          graphql_name "VerifiedPersonalInformationNode"

          field :first_name, GraphQL::Types::String, null: false
          field :last_name, GraphQL::Types::String, null: false
          field :given_name, GraphQL::Types::String, "The name the person is called with.", null: false
          field :national_identification_number, GraphQL::Types::String, null: false
          field :municipality_of_residence, GraphQL::Types::String, "Official municipality of residence in Finland as a free form text.", null: false
          field :municipality_of_residence_number, GraphQL::Types::String, "Official municipality of residence in Finland as an official number.", null: false
          field :permanent_address, VerifiedPersonalInformationAddressNode, "The permanent residency address in Finland.", null: true
          field :temporary_address, VerifiedPersonalInformationAddressNode, "The temporary residency address in Finland.", null: true
          field :permanent_foreign_address, VerifiedPersonalInformationForeignAddressNode, "The permanent foreign (i.e. not in Finland) residency address.", null: true
        end
      end
    end
  end
end
