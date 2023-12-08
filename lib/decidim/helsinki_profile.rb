# frozen_string_literal: true

require "omniauth"
require "omniauth/strategies/helsinki"
require "henkilotunnus"

require_relative "helsinki_profile/version"
require_relative "helsinki_profile/engine"
require_relative "helsinki_profile/authentication"
require_relative "helsinki_profile/verification"
require_relative "helsinki_profile/mail_interceptors"
require_relative "helsinki_profile/oidc"
require_relative "helsinki_profile/gdpr_api"

module Decidim
  module HelsinkiProfile
    autoload :FormBuilder, "decidim/helsinki_profile/form_builder"

    include ActiveSupport::Configurable

    # Defines the email domain for the auto-generated email addresses for the
    # user accounts. This is only used if the user does not have an email
    # address returned by HelsinkiProfile. Not all people have email address
    # stored there and some people may have incorrect email address stored
    # there.
    #
    # In case this is defined, the user will be automatically assigned an email
    # such as "helsinkiprofile-identifier@auto-email-domain.fi" upon their
    # registration.
    #
    # In case this is not defined, the default is the organization's domain.
    config_accessor :auto_email_domain

    # The requested OpenID scopes for the Omniauth strategy. The data returned
    # by the authentication service can differ depending on the defined scopes.
    #
    # See: https://openid.net/specs/openid-connect-basic-1_0.html#Scopes
    config_accessor :auth_scopes do
      [:openid, :email, :profile]
    end

    # Set this to `false` in case the Helsinki profile handover has not been
    # completed. Otherwise the authentication requests may fail against the
    # legacy authentication server due to invalid scopes.
    config_accessor :gdpr_authorization do
      true
    end

    # Allows changing the auth service name in case we need to perform a
    # "handover" process from the legacy authentication server. Once Helsinki
    # profile is ready to be used, this configuration is no longer needed.
    #
    # This needs to happen within the `:before_configuration` hook inside the
    # application.
    config_accessor :auth_service_name do
      "helsinki"
    end

    # Allows customizing the authorization workflow e.g. for adding custom
    # workflow options or configuring an action authorizer for the
    # particular needs.
    config_accessor :workflow_configurator do
      lambda do |workflow|
        workflow.expires_in = 90.days
      end
    end

    # Allows customizing parts of the authentication flow such as validating
    # the authorization data before allowing the user to be authenticated.
    config_accessor :authenticator_class do
      Decidim::HelsinkiProfile::Authentication::Authenticator
    end

    # Allows customizing how the authorization metadata gets collected from
    # the OAuth attributes passed from the authorization endpoint.
    config_accessor :metadata_collector_class do
      Decidim::HelsinkiProfile::Verification::MetadataCollector
    end

    # The user's email is confirmed at Helsinki profile's side, so we can trust
    # that the email always belongs to the user. Therefore, Helsinki profile
    # should not forward any email addresses that are "untrusted", i.e.
    # unverified.
    #
    # This feature may become useful in the future in case there will be
    # alternative authentication flows through the Helsinki profile.
    config_accessor :untrusted_email_providers do
      []
    end

    def self.configured?
      return false if omniauth_secrets.blank?

      omniauth_secrets[:enabled] && omniauth_secrets[:auth_uri].present?
    end

    def self.gdpr_scopes
      return {} unless configured?

      # See:
      # https://profile-api.dev.hel.ninja/docs/gdpr-api/
      # auth_uri = omniauth_secrets[:auth_uri]
      # prefix = "#{auth_uri}."
      # In the integration documentation it seems that the GDPR scopes were
      # defined without the service authentication URI as a prefix, although the
      # documentation instructs so.
      {
        query: "gdprquery",
        delete: "gdprdelete"
      }
    end

    # Make sure the SWD discovery requests (generated by the openid_connect gem)
    # will succeed also with the "http" URI scheme, so it does not force the
    # authentication endpoint to be secured (e.g. in development environment).
    #
    # This is needed both for the Omniauth strategy as well as the local
    # Oidc::Connector class.
    def self.discovery_request(uri)
      orig_url_builder = SWD.url_builder
      SWD.url_builder = URI::HTTP if uri.match?(%r{^http://})
      result = yield
      SWD.url_builder = orig_url_builder
      result
    end

    def self.authenticator_for(organization, oauth_hash)
      authenticator_class.new(organization, oauth_hash)
    end

    def self.omniauth_secrets
      @omniauth_secrets ||= begin
        configured_key = auth_service_name.to_sym
        Rails.application.secrets[:omniauth][configured_key] || Rails.application.secrets[:omniauth][:helsinki]
      end
    end

    def self.fix_omniauth_config!
      return unless configured?

      service_name = auth_service_name.to_sym
      return if service_name == :helsinki

      Rails.application.secrets[:omniauth].transform_keys! do |key|
        key == :helsinki ? service_name : key
      end
    end

    def self.omniauth_settings
      secrets = omniauth_secrets
      server_uri = secrets[:auth_uri]
      client_id = secrets[:auth_client_id]
      client_secret = secrets[:auth_client_secret]
      service_name = auth_service_name

      auth_uri = URI.parse(server_uri)
      {
        name: service_name.to_sym,
        strategy_class: OmniAuth::Strategies::Helsinki,
        issuer: server_uri,
        scope: auth_scopes,
        client_options: {
          port: auth_uri.port,
          scheme: auth_uri.scheme,
          host: auth_uri.host,
          identifier: client_id,
          secret: client_secret,
          redirect_uri: "#{application_host}/users/auth/#{service_name}/callback"
        },
        post_logout_redirect_uri: "#{application_host}/users/auth/#{service_name}/post_logout"
      }
    end

    # Used to determine the callback URLs.
    def self.application_host
      conf = Rails.application.config
      url_options = conf.action_controller.default_url_options
      url_options = conf.action_mailer.default_url_options if !url_options || !url_options[:host]
      url_options ||= {}
      host, port = host_and_port_setting(url_options)

      return "#{host}:#{port}" if port && [80, 443].exclude?(port.to_i)

      host
    end

    def self.host_and_port_setting(url_options)
      host = url_options[:host]
      port = url_options[:port]
      if host.blank?
        # Default to local development environment
        host = "http://localhost"
        port ||= 3000
      elsif host !~ %r{^https?://}
        protocol = url_options[:protocol] || "https"
        host = "#{protocol}://#{host}"
      end
      [host, port]
    end

    private_class_method :host_and_port_setting
  end
end
