# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      module TestApp
        module Rack
          autoload :App, "decidim/helsinki_profile/test/test_app/rack/app"
          autoload :Graphql, "decidim/helsinki_profile/test/test_app/rack/graphql"
          autoload :Oidc, "decidim/helsinki_profile/test/test_app/rack/oidc"
        end
      end
    end
  end
end
