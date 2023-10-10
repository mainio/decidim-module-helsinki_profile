# frozen_string_literal: true

require "spec_helper"

describe Decidim::HelsinkiProfile::Engine do
  it "mounts the routes to the core engine" do
    routes = double
    allow(Decidim::Core::Engine).to receive(:routes).and_return(routes)
    expect(routes).to receive(:prepend) do |&block|
      context = double
      expect(context).to receive(:mount).with(described_class => "/")
      context.instance_eval(&block)
    end

    run_initializer("decidim_helsinki_profile.mount_routes")
  end

  it "configures the Helsinki profile omniauth strategy for Devise" do
    expect(Devise).to receive(:setup) do |&block|
      config = double
      secrets = Rails.application.secrets[:omniauth][:helsinki]
      expect(config).to receive(:omniauth).with(
        :helsinki,
        {
          client_options: {
            host: "oicd.example.org",
            identifier: "auth-client",
            port: 443,
            redirect_uri: "http://localhost:3000/users/auth/helsinki/callback",
            scheme: "https",
            secret: "abcdef1234567890"
          },
          name: :helsinki,
          issuer: "https://oicd.example.org/auth/realms/helsinki-tunnistus",
          post_logout_redirect_uri: "http://localhost:3000/users/auth/helsinki/post_logout",
          scope: [:openid, :email, :profile, "https://api.hel.fi/auth/helsinkiprofile", secrets[:gdpr_uri]],
          strategy_class: OmniAuth::Strategies::Helsinki
        }
      )
      block.call(config)
    end

    run_initializer("decidim_helsinki_profile.setup")
  end

  it "configures the OmniAuth failure app" do
    expect(OmniAuth.config).to receive(:on_failure=) do |proc|
      env = double
      action = double
      allow(env).to receive(:[]).with("PATH_INFO").and_return(
        "/users/auth/helsinki"
      )
      expect(env).to receive(:[]=).with("devise.mapping", ::Devise.mappings[:user])
      allow(Decidim::HelsinkiProfile::OmniauthCallbacksController).to receive(
        :action
      ).with(:failure).and_return(action)
      expect(action).to receive(:call).with(env)

      proc.call(env)
    end

    run_initializer("decidim_helsinki_profile.setup")
  end

  it "falls back on the default OmniAuth failure app" do
    failure_app = double

    allow(OmniAuth.config).to receive(:on_failure).and_return(failure_app)
    expect(OmniAuth.config).to receive(:on_failure=) do |proc|
      env = double
      allow(env).to receive(:[]).with("PATH_INFO").and_return(
        "/something/else"
      )
      expect(failure_app).to receive(:call).with(env)

      proc.call(env)
    end

    run_initializer("decidim_helsinki_profile.setup")
  end

  it "adds the mail interceptor" do
    expect(ActionMailer::Base).to receive(:register_interceptor).with(
      Decidim::HelsinkiProfile::MailInterceptors::GeneratedRecipientsInterceptor
    )

    run_initializer("decidim_helsinki_profile.mail_interceptors")
  end

  def run_initializer(initializer_name)
    config = described_class.initializers.find do |i|
      i.name == initializer_name
    end
    config.run
  end
end
