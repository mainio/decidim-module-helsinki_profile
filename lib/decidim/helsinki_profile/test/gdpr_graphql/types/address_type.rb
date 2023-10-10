# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module GdprGraphql
        class AddressType < GraphQL::Schema::Enum
          graphql_name "AddressType"

          value "NONE"
          value "WORK"
          value "HOME"
          value "OTHER"
        end
      end
    end
  end
end
