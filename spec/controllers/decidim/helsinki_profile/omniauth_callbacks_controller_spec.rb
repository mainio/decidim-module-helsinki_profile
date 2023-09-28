# frozen_string_literal: true

require "spec_helper"

describe Decidim::HelsinkiProfile::OmniauthCallbacksController, type: :request do
  let(:organization) { create(:organization) }

  let(:uid) { SecureRandom.uuid }
  let(:email) { nil }
  let(:email_verified) { false }
  let(:name) { "#{given_name} #{family_name}" }
  let(:given_name) { "Jack" }
  let(:family_name) { "Bauer" }
  let(:amr) { ["suomi_fi"] }

  let(:oauth_hash) do
    {
      provider: "helsinki",
      uid: uid,
      info: oauth_info,
      extra: { raw_info: oauth_info.merge(oauth_extra) }
    }
  end
  let(:oauth_info) do
    {
      email: email,
      email_verified: email_verified,
      name: name,
      given_name: given_name,
      family_name: family_name,
      amr: amr
    }
  end
  let(:oauth_extra) do
    {
      national_id_num: "010400A901X"
    }
  end

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.add_mock(:helsinki, oauth_hash)

    # Set the correct host
    host! organization.host
  end

  after do
    OmniAuth.config.test_mode = false
  end

  describe "GET /users/auth/helsinki/callback" do
    let(:code) { SecureRandom.hex(16) }
    let(:state) { SecureRandom.hex(16) }

    context "when user isn't signed in" do
      let(:session) { nil }

      before do
        request_args = {}
        if session
          # Do a mock request in order to create a session
          get "/"
          session.each do |key, val|
            request.session[key.to_s] = val
          end
          request_args[:env] = {
            "rack.session" => request.session,
            "rack.session.options" => request.session.options
          }
        end

        get(
          "/users/auth/helsinki/callback?code=#{code}&state=#{state}",
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
        expect(authorization.metadata["family_name"]).to eq(family_name)
      end

      # Decidim core would want to redirect to the verifications path on the
      # first sign in but we don't want that to happen as the user is already
      # authorized during the sign in process.
      it "redirects to the root path by default after a successful registration and first sign in" do
        user = Decidim::User.last

        expect(user.sign_in_count).to eq(1)
        expect(response).to redirect_to("/")
      end

      context "when the session has a pending redirect" do
        let(:session) { { user_return_to: "/processes" } }

        it "redirects to the stored location by default after a successful registration and first sign in" do
          user = Decidim::User.last

          expect(user.sign_in_count).to eq(1)
          expect(response).to redirect_to("/processes")
        end
      end
    end

    context "when storing the email address" do
      let(:email) { "oauth.email@example.org" }
      let(:authenticator) do
        Decidim::HelsinkiProfile.authenticator_class.new(organization, oauth_hash)
      end

      before do
        allow(Decidim::HelsinkiProfile).to receive(:authenticator_for).and_return(authenticator)
      end

      context "when email is confirmed according to the authenticator" do
        let(:email_verified) { true }

        before do
          allow(Decidim::HelsinkiProfile).to receive(:untrusted_email_providers).and_return([])
        end

        it "creates the user account with the confirmed email address" do
          get(
            "/users/auth/helsinki/callback?code=#{code}&state=#{state}"
          )

          user = Decidim::User.last
          expect(user.email).to eq(email)
          expect(user.unconfirmed_email).to be_nil
        end
      end

      context "when email is unconfirmed according to the authenticator" do
        it "creates the user account with the confirmed email address" do
          get(
            "/users/auth/helsinki/callback?code=#{code}&state=#{state}"
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

      before do
        request_args = {}
        if session
          # Do a mock request in order to create a session
          get "/"
          session.each do |key, val|
            request.session[key.to_s] = val
          end
          request_args[:env] = {
            "rack.session" => request.session,
            "rack.session.options" => request.session.options
          }
        end

        sign_in confirmed_user
        get(
          "/users/auth/helsinki/callback?code=#{code}&state=#{state}",
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
          "/users/auth/helsinki/callback?code=#{code}&state=#{state}"
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
      let!(:identity) { create(:identity, user: another_user, provider: "helsinki", uid: uid, organization: organization) }

      before do
        sign_in confirmed_user
        get(
          "/users/auth/helsinki/callback?code=#{code}&state=#{state}"
        )
      end

      it "identifies user" do
        authorization = Decidim::Authorization.find_by(
          user: confirmed_user,
          name: "helsinki_idp"
        )
        expect(authorization).to be_nil
        expect(response).to redirect_to("/users/auth/helsinki/logout")
        expect(flash[:alert]).to eq(
          "Another user has already been identified using this identity. Please sign out and sign in again directly using Helsinki profile."
        )
      end
    end
  end
end
