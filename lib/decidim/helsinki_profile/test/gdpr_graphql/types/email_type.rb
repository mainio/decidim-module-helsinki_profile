# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module GdprGraphql
        class EmailType < GraphQL::Schema::Enum
          graphql_name "EmailType"

          value "NONE"
          value "WORK"
          value "PERSONAL"
          value "OTHER"
        end
      end
    end
  end
end
