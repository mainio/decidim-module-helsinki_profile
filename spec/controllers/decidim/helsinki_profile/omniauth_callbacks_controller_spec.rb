# frozen_string_literal: true

require "spec_helper"

describe Decidim::HelsinkiProfile::OmniauthCallbacksController, type: :request do
  let(:organization) { create(:organization) }

  let(:email) { nil }
  let(:email_verified) { false }
  let(:name) { "#{given_name} #{last_name}" }
  let(:given_name) { profile[:first_name] }
  let(:last_name) { profile[:last_name] }
  let(:amr) { ["suomi_fi"] }

  let(:auth_server) { Decidim::HelsinkiProfile::Test::OidcServer.get(:auth) }
  let(:profile_api) { Decidim::HelsinkiProfile::Test::ProfileGraphql::Server.instance }
  let(:profile) { create(:helsinki_profile_person) }
  let(:token_sub) { profile[:id] }

  let(:request_args) do
    if session
      session.each do |key, val|
        request.session[key.to_s] = val
      end
    end

    {
      env: {
        "rack.session" => request.session,
        "rack.session.options" => request.session.options
      }
    }
  end
  let(:omniauth_state) { request.session["omniauth.state"] }
  let(:code) { SecureRandom.hex(16) }
  let(:id_token_payload) { { groups: ["testing"] } }

  before do
    profile_api.register_profile(profile)

    # Set the correct host
    host! organization.host

    # Do the initial authentication "request phase" call in order to initialize
    # the session variables to validate the callback request properly. This
    # tests the authentication flow sort of "end-to-end" (served by the local
    # dummy "servers") in order to generate the tokens properly through the
    # Omniauth strategy and initiate the profile API requests correctly.
    post("/users/auth/helsinki")
  end

  describe "GET /users/auth/helsinki/callback" do
    context "when user is not signed in" do
      let(:session) { nil }

      before do
        get(
          "/users/auth/helsinki/callback?code=#{code}&state=#{omniauth_state}",
          **request_args
        )
      end

      it "creates authorization" do
        authorization = Decidim::Authorization.last
        expect(authorization).not_to be_nil
        expect(authorization.name).to eq("helsinki_idp")
        expect(authorization.metadata["name"]).to eq(name)
        expect(authorization.metadata["service"]).to eq(amr)
        expect(authorization.metadata["first_name"]).to eq(given_name)
        expect(authorization.metadata["given_name"]).to eq(given_name)
        expect(authorization.metadata["last_name"]).to eq(last_name)
      end

      # Decidim core would want to redirect to the verifications path on the
      # first sign in but we don't want that to happen as the user is already
      # authorized during the sign in process.
      it "redirects to the root path by default after a successful registration and first sign in" do
        user = Decidim::User.last

        expect(user.sign_in_count).to eq(1)
        expect(response).to redirect_to("/")
      end

      it "creates a session info object for the user" do
        info = Decidim::HelsinkiProfile::SessionInfo.find_by(user: Decidim::User.last)

        expect(info).to be_a(Decidim::HelsinkiProfile::SessionInfo)

        decoded = JSON::JWT.decode(info.id_token, :skip_verification).to_h
        expect(decoded.symbolize_keys!).to include(id_token_payload)
      end

      context "when the session has a pending redirect" do
        let(:session) { { user_return_to: "/processes" } }

        it "redirects to the stored location by default after a successful registration and first sign in" do
          user = Decidim::User.last

          expect(user.sign_in_count).to eq(1)
          expect(response).to redirect_to("/processes")
        end
      end

      # This spec is just to ensure that the ID token is not stored inside a
      # cookie as that would cause a cookie overflow exception
      # (ActionDispatch::Cookies::CookieOverflow) in case it exceeds 4kB in
      # size.
      context "when the id token is very long" do
        # Generate a payload of at least 4kB.
        let(:id_token_payload) do
          { groups: 4.times.map { |num| (97 + num).chr * 1024 } }
        end

        it "does not cause an exception" do
          user = Decidim::User.last

          expect(user.sign_in_count).to eq(1)
          expect(response).to redirect_to("/")
        end
      end
    end

    context "when storing the email address" do
      let(:email) { profile.dig(:primary_email, :email) }

      context "when email is verified according to the authenticator" do
        before do
          allow(Decidim::HelsinkiProfile).to receive(:untrusted_email_providers).and_return([])
        end

        it "creates the user account with the verified email address" do
          get(
            "/users/auth/helsinki/callback?code=#{code}&state=#{omniauth_state}",
            **request_args
          )

          user = Decidim::User.last
          expect(user.email).to eq(email)
          expect(user.unconfirmed_email).to be_nil
        end

        context "when the user is an admin with a pending password change request" do
          let!(:user) { create(:user, :admin, organization: organization, email: email, sign_in_count: 1, password_updated_at: 1.year.ago) }

          it "redirects to the password change path" do
            get(
              "/users/auth/helsinki/callback?code=#{code}&state=#{omniauth_state}"
            )

            expect(response).to redirect_to("/change_password")
          end
        end
      end

      context "when email is unverified according to the authenticator" do
        let(:profile) do
          create(:helsinki_profile_person, primary_email: create(:helsinki_profile_email, :primary, :unverified))
        end

        it "creates the user account with the confirmed email address" do
          get(
            "/users/auth/helsinki/callback?code=#{code}&state=#{omniauth_state}",
            **request_args
          )

          user = Decidim::User.last
          expect(user.email).to match(/helsinki-[a-z0-9]{32}@[0-9]+.lvh.me/)
          expect(user.unconfirmed_email).to eq(email)
        end
      end
    end

    context "when user is signed in" do
      let(:session) { nil }
      let!(:confirmed_user) do
        create(:user, :confirmed, organization: organization)
      end
      let!(:previous_info) do
        Decidim::HelsinkiProfile::SessionInfo.create(user: confirmed_user, id_token: "previous")
      end

      before do
        sign_in confirmed_user
        get(
          "/users/auth/helsinki/callback?code=#{code}&state=#{omniauth_state}",
          **request_args
        )
      end

      it "identifies user" do
        authorization = Decidim::Authorization.find_by(
          user: confirmed_user,
          name: "helsinki_idp"
        )

        expect(authorization).not_to be_nil
        expect(authorization.user).to eq(confirmed_user)
      end

      it "creates a new session info object for the user" do
        expect(Decidim::HelsinkiProfile::SessionInfo.find_by(id: previous_info.id)).to be_nil

        info = Decidim::HelsinkiProfile::SessionInfo.find_by(user: Decidim::User.last)
        expect(info).to be_a(Decidim::HelsinkiProfile::SessionInfo)

        decoded = JSON::JWT.decode(info.id_token, :skip_verification).to_h
        expect(decoded.symbolize_keys!).to include(id_token_payload)
      end

      it "redirects to the root path" do
        expect(response).to redirect_to("/")
      end

      context "when the session has a pending redirect" do
        let(:session) { { user_return_to: "/processes" } }

        it "redirects to the stored location" do
          expect(response).to redirect_to("/processes")
        end
      end
    end

    context "when using remember me" do
      let(:confirmed_user) { create(:user, :confirmed, organization: organization) }

      before do
        sign_in confirmed_user
        confirmed_user.remember_me!
        expect(confirmed_user.remember_created_at?).to be(true)
        get(
          "/users/auth/helsinki/callback?code=#{code}&state=#{omniauth_state}",
          **request_args
        )
      end

      it "forgets user's remember me" do
        authorization = Decidim::Authorization.last
        expect(authorization.metadata["service"]).to eq(["suomi_fi"])
        expect(authorization.user.remember_created_at).to be_nil
      end
    end

    context "when identity is bound to another user" do
      let(:confirmed_user) { create(:user, :confirmed, organization: organization) }
      let(:another_user) { create(:user, :confirmed, organization: organization) }
      let!(:identity) { create(:identity, user: another_user, provider: "helsinki", uid: profile[:id], organization: organization) }

      before do
        sign_in confirmed_user
        get(
          "/users/auth/helsinki/callback?code=#{code}&state=#{omniauth_state}",
          **request_args
        )
      end

      it "identifies user" do
        authorization = Decidim::Authorization.find_by(
          user: confirmed_user,
          name: "helsinki_idp"
        )
        expect(authorization).to be_nil

        info = Decidim::HelsinkiProfile::SessionInfo.find_by(user: confirmed_user)
        expect(info).to be_nil

        redirect_uri = URI.parse(response.location)
        redirect_params = Rack::Utils.parse_query(redirect_uri.query).symbolize_keys!

        expect(redirect_uri.host).to eq(organization.host)
        expect(redirect_uri.path).to eq("/users/auth/helsinki/logout")
        expect(redirect_params).to match(id_token_hint: /\A[^\s]+\z/)
        expect(flash[:alert]).to eq(
          "Another user has already been identified using this identity. Please sign out and sign in again directly using Helsinki profile."
        )
      end
    end
  end

  describe "GET /users/auth/helsinki/silent" do
    it "responds with no content" do
      get("/users/auth/helsinki/silent?code=#{code}&state=#{omniauth_state}", **request_args)
      expect(response.code).to eq("204")
    end

    context "when the user is signed in" do
      let(:user) { create(:user, :confirmed, organization: organization) }

      before do
        sign_in user
      end

      it "responds with success" do
        get("/users/auth/helsinki/silent?code=#{code}&state=#{omniauth_state}", **request_args)
        expect(response.code).to eq("200")
        expect(response.body).to eq("Success")
      end
    end
  end
end
