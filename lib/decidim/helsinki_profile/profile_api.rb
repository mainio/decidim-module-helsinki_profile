# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module ProfileApi
      autoload :Client, "decidim/helsinki_profile/profile_api/client"

      class ProfileApiError < StandardError; end

      class AuthenticationError < ProfileApiError; end

      class QueryError < ProfileApiError; end
    end
  end
end
