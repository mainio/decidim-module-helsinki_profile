# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module GdprGraphql
        class AuthorizedField < GraphQL::Schema::Field
          def authorized?(obj, args, ctx)
            super && ctx[:current_profile].present?
          end
        end
      end
    end
  end
end
