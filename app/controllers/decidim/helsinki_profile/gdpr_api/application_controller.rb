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
            render body: nil, status: :no_content, content_type: "application/json"
          end
        end

        def error(code, message, status: :internal_server_error)
          render body: {
            code: code,
            message: message
          }, status: status, content_type: "application/json"
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
            user: current_organization.users,
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
          @oidc ||= Decidim::HelsinkiProfile::Oidc::Connector.new(:auth)
        end
      end
    end
  end
end
