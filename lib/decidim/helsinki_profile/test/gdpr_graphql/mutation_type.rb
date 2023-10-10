# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module GdprGraphql
        # This type represents the root mutation type of the GDPR API
        class MutationType < Decidim::Api::Types::BaseObject
          description "The root mutation of this schema"
        end
      end
    end
  end
end
