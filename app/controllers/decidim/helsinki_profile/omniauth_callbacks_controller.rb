# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    class OmniauthCallbacksController < ::Decidim::Devise::OmniauthRegistrationsController
      include Decidim::HelsinkiProfile::SessionManagement

      # Make the view helpers available needed in the views
      helper Decidim::HelsinkiProfile::Engine.routes.url_helpers
      helper_method :omniauth_registrations_path

      skip_before_action :verify_authenticity_token, only: [:helsinki, :failure]
      skip_after_action :verify_same_origin_request, only: [:helsinki, :failure]

      # This is called always after the user returns from the authentication
      # flow from the HelsinkiProfile identity provider.
      def helsinki
        # This needs to be here in order to send the logout request to
        # HelsinkiProfile in case the sign in fails. Note that the
        # HelsinkiProfile sign out flow does not currently support the
        # "post_logout_redirect_uri" parameter, so the user may be left at
        # HelsinkiProfile after the sign out. This is more secure but may leave
        # some users confused. Should only happen if the authentication
        # validation fails.
        session["decidim-helsinkiprofile.signed_in"] = true

        authenticator.validate!

        if user_signed_in?
          # The user is most likely returning from an authorization request
          # because they are already signed in. In this case, add the
          # authorization and redirect the user back to the authorizations view.
          store_id_token_for!(current_user)

          # Make sure the user has an identity created in order to aid future
          # HelsinkiProfile sign ins. In case this fails, it will raise a
          # Decidim::HelsinkiProfile::Authentication::IdentityBoundToOtherUserError
          # which is handled below.
          authenticator.identify_user!(current_user)

          # Add the authorization for the user
          return fail_authorize unless authorize_user(current_user)

          # Forget the user regardless of the remember me configuration
          current_user.forget_me!
          cookies.delete :remember_user_token, domain: current_organization.host
          cookies.delete :remember_admin_token, domain: current_organization.host
          cookies.update response.cookies

          # Show the success message and redirect back to the authorizations
          flash[:notice] = t(
            "authorizations.create.success",
            scope: "decidim.helsinki_profile.verification"
          )
          return redirect_to(
            stored_location_for(resource || :user) ||
            decidim.root_path
          )
        end

        # Normal authentication request, proceed with Decidim's internal logic.
        send(:create)
      rescue Decidim::HelsinkiProfile::Authentication::ValidationError => e
        fail_authorize(e.validation_key)
      rescue Decidim::HelsinkiProfile::Authentication::IdentityBoundToOtherUserError
        fail_authorize(:identity_bound_to_other_user)
      end

      def failure; end

      # This should not do anything as it is a callback for OIDC "silent"
      # authentication, i.e. when the authentication request was initiated with
      # `prompt=none`. It could be used for SPA flows to fetch a refresh token.
      def helsinki_silent
        return head :no_content unless user_signed_in?

        render body: "Success"
      end

      # This is overridden method from the Devise controller helpers
      # This is called when the user is successfully authenticated which means
      # that we also need to add the authorization for the user automatically
      # because a succesful HelsinkiProfile authentication means the user has been
      # successfully authorized as well.
      def sign_in_and_redirect(resource_or_scope, *args)
        if resource_or_scope.is_a?(::Decidim::User)
          store_id_token_for!(resource_or_scope)

          # Add authorization for the user
          return fail_authorize unless authorize_user(resource_or_scope)
        end

        super
      end

      # Disable authorization redirect for the first login
      def first_login_and_not_authorized?(_user)
        false
      end

      private

      def store_id_token_for!(user)
        return unless user

        Decidim::HelsinkiProfile::SessionInfo.destroy_by(user:)

        id_token = request.env["omniauth-helsinki.id_token"]
        return unless id_token

        Decidim::HelsinkiProfile::SessionInfo.create!(user:, id_token:)
      end

      def authorize_user(user)
        authenticator.authorize_user!(user)
      rescue Decidim::HelsinkiProfile::Authentication::AuthorizationBoundToOtherUserError
        nil
      end

      def fail_authorize(failure_message_key = :already_authorized)
        flash[:alert] = t(
          "failure.#{failure_message_key}",
          scope: "decidim.helsinki_profile.omniauth_callbacks"
        )
        return openid_sign_out(current_user) if session.delete("decidim-helsinkiprofile.signed_in")

        redirect_path = stored_location_for(resource || :user) || decidim.root_path
        redirect_to redirect_path
      end

      # Needs to be specifically defined because the core engine routes are not
      # all properly loaded for the view and this helper method is needed for
      # defining the omniauth registration form's submit path.
      def omniauth_registrations_path(resource)
        Decidim::Core::Engine.routes.url_helpers.omniauth_registrations_path(resource)
      end

      # Private: Create form params from omniauth hash
      # Since we are using trusted omniauth data we are generating a valid signature.
      def user_params_from_oauth_hash
        authenticator.user_params_from_oauth_hash
      end

      def authenticator
        @authenticator ||= Decidim::HelsinkiProfile.authenticator_for(
          current_organization,
          oauth_hash
        )
      end

      def verified_email
        authenticator.verified_email
      end
    end
  end
end
