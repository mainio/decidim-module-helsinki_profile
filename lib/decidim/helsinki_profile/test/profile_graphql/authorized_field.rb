# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module ProfileGraphql
        class AuthorizedField < GraphQL::Schema::Field
          def initialize(*args, required_permission: nil, **kwargs, &block)
            @required_permission = required_permission
            # Pass on the default args:
            super(*args, **kwargs, &block)
          end

          def to_graphql
            field_defn = super # Returns a GraphQL::Field
            field_defn.metadata[:required_permission] = @required_permission
            field_defn
          end

          def authorized?(obj, args, ctx)
            return false unless super
            return false if ctx[:current_profile].blank?
            return false unless permission_satisfied?(ctx)

            true
          end

          private

          def permission_satisfied?(ctx)
            return true if @required_permission.blank?
            return false if ctx[:permissions].blank?

            ctx[:permissions][@required_permission]
          end
        end
      end
    end
  end
end
