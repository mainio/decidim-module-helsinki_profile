# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module GdprGraphql
        # Note that this is only a subset of the profile that is needed for the
        # integration to work correctly.
        class ProfileNode < Decidim::Api::Types::BaseObject
          graphql_name "ProfileNode"

          field_class AuthorizedField

          field :id, GraphQL::Types::ID, null: false
          field :first_name, GraphQL::Types::String, null: false
          field :last_name, GraphQL::Types::String, null: false
          field :nickname, GraphQL::Types::String, null: false
          field :language, GraphQL::Types::String, null: true
          field :primary_email, EmailNode, null: true
          field :primary_address, AddressNode, null: true
          field :verified_personal_information, VerifiedPersonalInformationNode, null: true, required_permission: :verified_information
        end
      end
    end
  end
end
