# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module SessionManagement
      extend ActiveSupport::Concern

      def openid_sign_out(user)
        user_info = Decidim::HelsinkiProfile::SessionInfo.find_by(user:) if user
        user_info&.destroy!

        # The ID token has to be provided for the logout request in order for
        # the authenticating service to end the session correctly for the user
        # and also for the after logout path to work correctly when returning
        # from the service. The Omniauth strategy handles passing this
        # parameter to the actual logout request.
        redirect_to decidim_helsinki_profile.user_helsinki_omniauth_logout_path(
          id_token_hint: user_info&.id_token || request.env["omniauth-helsinki.id_token"]
        )
      end
    end
  end
end
