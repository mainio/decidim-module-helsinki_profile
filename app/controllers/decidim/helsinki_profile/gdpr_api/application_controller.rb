# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module GdprApi
      class ApplicationController < ::Decidim::HelsinkiProfile::ApplicationController
        # These endpoints are meant to be used cross-origin without local
        # authenticity token checks. The authentication is done separately for
        # these APIs.
        skip_before_action :verify_authenticity_token
        skip_after_action :verify_same_origin_request

        before_action :authorize!, :identify!

        rescue_from HelsinkiProfile::Oidc::InvalidTokenError, HelsinkiProfile::Oidc::InvalidScopeError, with: :unauthorized
        rescue_from UnknownUserError, with: :not_found

        private

        attr_reader :profile_user

        def unauthorized
          render body: nil, status: :unauthorized, content_type: "application/json"
        end

        def not_found
          render body: nil, status: :not_found, content_type: "application/json"
        end

        def success(data = nil)
          if data.is_a?(Enumerable)
            render json: data
          elsif data
            render body: data, content_type: "application/json"
          else
            head :no_content
          end
        end

        def error(code, message, status: :internal_server_error)
          render body: {
            code:,
            message:
          }, status:, content_type: "application/json"
        end

        def authorize!
          oidc.authorize_header!(request.headers["Authorization"], nonce: params[:nonce], sub: params[:uuid])
        end

        def identify!
          uid_signature = Decidim::OmniauthRegistrationForm.create_signature(
            "helsinki",
            params[:uuid]
          )
          identity = Identity.find_by(
            # Note that the `.unscoped` call is relevant for the privacy module
            # which hides the non-published users by default.
            user: Decidim::User.unscoped.where(organization: current_organization),
            provider: "helsinki",
            uid: uid_signature
          )
          raise UnknownUserError unless identity

          @profile_user = identity&.user

          raise UnknownUserError unless profile_user
          raise UnknownUserError if profile_user.deleted?
        end

        def validate_scope!(key)
          requested_scope = Decidim::HelsinkiProfile.gdpr_scopes[key]
          oidc.validate_scope!(requested_scope)
        end

        def oidc
          # Note that the `:gdpr_client_secret` configuration below does not
          # need to be set for environments that do not use any of the JWT token
          # signing algorithms that require the secret to verify the signature.
          #
          # These algorithms are tested during testing but in the actual
          # Keycloak servers, it is not required, i.e. it can be `nil` or unset.
          @oidc ||= Decidim::HelsinkiProfile::Oidc::Connector.new(
            Decidim::HelsinkiProfile.omniauth_secrets[:auth_uri],
            Decidim::HelsinkiProfile.omniauth_secrets[:gdpr_client_id],
            Decidim::HelsinkiProfile.omniauth_secrets[:gdpr_client_secret]
          )
        end
      end
    end
  end
end
