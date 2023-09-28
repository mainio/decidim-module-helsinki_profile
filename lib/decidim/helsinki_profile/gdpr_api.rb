# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module GdprApi
      autoload :UserSerializer, "decidim/helsinki_profile/gdpr_api/user_serializer"

      class UnknownUserError < StandardError; end
    end
  end
end
