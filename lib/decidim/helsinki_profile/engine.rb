# frozen_string_literal: true

require "omniauth/rails_csrf_protection/token_verifier"

module Decidim
  module HelsinkiProfile
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::HelsinkiProfile

      routes do
        # GDPR API
        namespace :gdpr_api, path: "gdpr-api" do
          namespace :v1 do
            # GET /gdpr-api/v1/profiles/:uuid
            # DELETE /gdpr-api/v1/profiles/:uuid
            resources :profiles, only: [:show, :destroy], param: :uuid
          end
        end

        devise_scope :user do
          # Manually map the omniauth routes for Devise because the default
          # routes are mounted by core Decidim. This is because we want to map
          # these routes to the local callbacks controller instead of the
          # Decidim core.
          # See: https://git.io/fjDz1
          match(
            "/users/auth/helsinki",
            to: "omniauth_callbacks#passthru",
            as: "user_helsinki_omniauth_authorize",
            via: [:get, :post]
          )

          match(
            "/users/auth/helsinki/callback",
            to: "omniauth_callbacks#helsinki",
            as: "user_helsinki_omniauth_callback",
            via: [:get, :post]
          )

          match(
            "/users/auth/helsinki/logout",
            to: "sessions#helsinki_logout",
            as: "user_helsinki_omniauth_logout",
            via: [:get, :post]
          )

          match(
            "/users/auth/helsinki/post_logout",
            to: "sessions#post_logout",
            as: "user_helsinki_omniauth_post_logout",
            via: [:get]
          )

          # Manually map the sign out path in order to control the sign out
          # flow through OmniAuth when the user signs out from the service.
          # In these cases, the user needs to be also signed out from Suomi.fi
          # which is handled by the OmniAuth strategy.
          match(
            "/users/sign_out",
            to: "sessions#destroy",
            as: "destroy_user_session",
            via: [:delete, :post]
          )
        end
      end

      initializer "decidim_helsinki_profile.mount_routes", before: :add_routing_paths do
        # Mount the engine routes to Decidim::Core::Engine because otherwise
        # they would not get mounted properly. Note also that we need to prepend
        # the routes in order for them to override Decidim's own routes for the
        # "helsinki profile" authentication.
        Decidim::Core::Engine.routes.prepend do
          mount Decidim::HelsinkiProfile::Engine => "/"
        end
      end

      initializer "decidim_helsinki_profile.customizations", after: "decidim.action_controller" do
        config.to_prepare do
          Decidim::CreateOmniauthRegistration.include Decidim::HelsinkiProfile::CreateOmniauthRegistrationOverride
          Decidim::OmniauthRegistrationForm.include Decidim::HelsinkiProfile::OmniauthRegistrationFormExtensions
        end
      end

      initializer "decidim_helsinki_profile.setup", before: "devise.omniauth" do
        next unless Decidim::HelsinkiProfile.configured?

        OmniAuth.config.request_validation_phase = ::OmniAuth::RailsCsrfProtection::TokenVerifier.new

        # Configure the OmniAuth strategy for Devise
        ::Devise.setup do |config|
          config.omniauth(
            :helsinki,
            Decidim::HelsinkiProfile.omniauth_settings
          )
        end

        # Customized version of Devise's OmniAuth failure app in order to handle
        # the failures properly. Without this, the failure requests would end
        # up in an ActionController::InvalidAuthenticityToken exception.
        devise_failure_app = OmniAuth.config.on_failure
        OmniAuth.config.on_failure = proc do |env|
          if env["PATH_INFO"] =~ %r{^/users/auth/helsinki(/.*)?}
            env["devise.mapping"] = ::Devise.mappings[:user]
            Decidim::HelsinkiProfile::OmniauthCallbacksController.action(
              :failure
            ).call(env)
          else
            # Call the default for others.
            devise_failure_app.call(env)
          end
        end
      end

      initializer "decidim_helsinki_profile.mail_interceptors" do
        ActionMailer::Base.register_interceptor(
          MailInterceptors::GeneratedRecipientsInterceptor
        )
      end
    end
  end
end
