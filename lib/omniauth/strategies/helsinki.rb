# frozen_string_literal: true

require "omniauth_openid_connect"

module OmniAuth
  module Strategies
    class Helsinki < OpenIDConnect
      option :name, :helsinki
      option :discovery, true
      option :scope, [:openid, :email, :profile]

      # Defines the lang parameters to check from the request phase request
      # parameters. A valid language will be added to the IdP sign in redirect
      # URL as the last parameter.
      #
      # In case a valid language cannot be parsed from the parameter, the lang
      # parameter will omitted when the authentication service will determine
      # the UI language.
      option :lang_params, %w(locale)

      # The omniauth_openid_connect gem relies on the openid_connect which uses
      # a request client inherited from rack-oauth2. This request client does
      # the access token requests to the authentication server and by default
      # it uses HTTP basic authentication. This does not work if the client
      # credentials contain specific characters (such as ":") which is why we
      # define the "other" authentication method when they are included in a
      # normal POST request. There is no `:other` auth method in the client but
      # with an unknown method it goes to the else block which does exactly
      # this. See: https://git.io/JfSD0
      option :client_auth_method, :other

      def config
        Decidim::HelsinkiProfile.discovery_request(options.issuer) do
          super
        end
      end

      def authorize_uri
        client.redirect_uri = redirect_uri
        opts = {
          response_type: options.response_type,
          scope: options.scope,
          state: new_state,
          login_hint: options.login_hint,
          prompt: options.prompt,
          nonce: (new_nonce if options.send_nonce),
          hd: options.hd
        }

        # Pass the ?ui_locales=xx to the authentication service
        lang = language_for_openid_connect
        opts[:ui_locales] = lang if lang

        client.authorization_uri(opts.compact)
      end

      def end_session_uri
        return unless end_session_endpoint_is_valid?

        end_session_uri = URI(client_options.end_session_endpoint)
        end_session_uri.query = encoded_post_logout_query
        end_session_uri.to_s
      end

      def other_phase
        return silent_phase if silent_path_pattern.match?(current_path)

        super
      end

      def silent_phase
        options.issuer = issuer if options.issuer.to_s.empty?
        discover!

        opts = {
          response_type: options.response_type,
          response_mode: options.response_mode,
          scope: options.scope,
          state: new_state,
          login_hint: params["login_hint"],
          ui_locales: params["ui_locales"],
          claims_locales: params["claims_locales"],
          prompt: "none",
          nonce: (new_nonce if options.send_nonce),
          hd: options.hd,
          acr_values: options.acr_values
        }

        opts.merge!(options.extra_authorize_params) unless options.extra_authorize_params.empty?

        options.allow_authorize_params.each do |key|
          opts[key] = request.params[key.to_s] unless opts.has_key?(key)
        end

        redirect client.authorization_uri(opts.compact)
      end

      private

      def verify_id_token!(id_token)
        session["omniauth-helsinki.id_token"] = id_token if id_token

        super
      end

      def silent_path_pattern
        @silent_path_pattern ||= %r{\A#{Regexp.quote(request_path)}/silent}
      end

      def encoded_post_logout_query
        # Store the post logout query because it is fetched multiple times and
        # the ID token is deleted during the first time.
        @encoded_post_logout_query ||= begin
          logout_params = {
            id_token_hint: session.delete("omniauth-helsinki.id_token"),
            post_logout_redirect_uri: options.post_logout_redirect_uri
          }.compact

          URI.encode_www_form(logout_params)
        end
      end

      # Determines the application language parameter from one of the configured
      # parameters. Only returns if the parameter is set and contains a value
      # accepted by the authentication service.
      def application_language_param
        return nil unless options.lang_params.is_a?(Array)

        options.lang_params.each do |param|
          next unless request.params.has_key?(param.to_s)

          lang = parse_language_value(request.params[param.to_s])
          return param.to_s unless lang.nil?
        end

        nil
      end

      # Determines the correct language for the authentication service. Returns
      # the langauge passed through the URL if the language parameter is set and
      # contains a value accepted by the authentication service. Otherwise it
      # will try to fetch the locale from the I18n class if that is available
      # and returns a locale accepted by the authentication service.
      def language_for_openid_connect
        param = application_language_param
        lang = nil
        lang = parse_language_value(request.params[param.to_s]) if param
        return lang if lang

        # Default to I18n locale if it is available
        parse_language_value(I18n.locale.to_s) if Object.const_defined?("I18n")
      end

      # Parses a langauge value from the following types of strings:
      # - fi
      # - fi_FI
      # - fi-FI
      #
      # Returns a string containing the language code if the authentication
      # service supports that language.
      def parse_language_value(string)
        language = string.sub("_", "-").split("-").first

        language if language =~ /^(fi|sv|en)$/
      end
    end
  end
end
