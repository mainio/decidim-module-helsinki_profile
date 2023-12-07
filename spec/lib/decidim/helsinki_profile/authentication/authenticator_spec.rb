# frozen_string_literal: true

require "spec_helper"

describe Decidim::HelsinkiProfile::Authentication::Authenticator do
  subject { described_class.new(organization, oauth_hash) }

  let(:organization) { create(:organization) }
  let(:auth_server) { Decidim::HelsinkiProfile::Test::OidcServer.get(:auth) }
  let(:gdpr_api) { Decidim::HelsinkiProfile::Test::GdprGraphql::Server.instance }
  let(:profile) { create(:helsinki_profile_person) }
  let(:oauth_hash) do
    {
      provider: oauth_provider,
      uid: oauth_uid,
      info: oauth_info,
      extra: {
        raw_info: oauth_raw_info
      },
      credentials: { token: token.to_s }
    }
  end
  let(:token) do
    auth_server.token(
      sub: oauth_uid,
      amr: amr,
      scope: Decidim::HelsinkiProfile.omniauth_secrets[:gdpr_uri]
    )
  end
  let(:oauth_provider) { "provider" }
  let(:oauth_uid) { profile[:id] }
  let(:oauth_name) { "Marja Mainio" }
  let(:oauth_image) { nil }
  let(:oauth_info) do
    {
      name: oauth_name,
      image: oauth_image
    }
  end
  let(:oauth_raw_info) { base_oauth_raw_info }
  let(:base_oauth_raw_info) do
    {
      name: "Marja Mirja Mainio",
      given_name: "Marja",
      family_name: "Mainio",
      national_id_num: "150785-994A"
    }
  end
  let(:amr) { %w(suomi_fi) }

  before do
    gdpr_api.register_profile(profile)
  end

  describe "#verified_email" do
    context "when email is available in the OIDC attributes and is reported as verified" do
      let(:oauth_info) { { email: "user@example.org" } }
      let(:email_verified) { true }
      let(:oauth_raw_info) { base_oauth_raw_info.merge(email_verified: email_verified) }

      context "with suomi_fi" do
        it "returns the email from OIDC attributes" do
          expect(subject.verified_email).to match("user@example.org")
        end
      end

      context "with another identity service" do
        let(:amr) { %w(weak) }

        it "returns the email from OIDC attributes" do
          expect(subject.verified_email).to eq("user@example.org")
        end

        context "when the email is not verified" do
          let(:email_verified) { false }

          it "returns the generated email" do
            expect(subject.verified_email).to match(/helsinki-[a-z0-9]{32}@[0-9]+.lvh.me/)
          end
        end

        context "when the email is blank" do
          let(:oauth_info) { { email: nil } }

          it "returns the generated email" do
            expect(subject.verified_email).to match(/helsinki-[a-z0-9]{32}@[0-9]+.lvh.me/)
          end
        end
      end
    end

    context "when email is not available in the OIDC attributes" do
      it "auto-creates the email using the known pattern" do
        expect(subject.verified_email).to match(/helsinki-[a-z0-9]{32}@[0-9]+.lvh.me/)
      end

      context "and auto_email_domain is not defined" do
        before do
          allow(Decidim::HelsinkiProfile).to receive(:auto_email_domain).and_return(nil)
        end

        it "auto-creates the email using the known pattern" do
          expect(subject.verified_email).to match(/helsinki-[a-z0-9]{32}@#{organization.host}/)
        end
      end
    end
  end

  describe "#user_params_from_oauth_hash" do
    shared_examples_for "expected hash" do
      it "returns the expected hash" do
        signature = ::Decidim::OmniauthRegistrationForm.create_signature(
          oauth_provider,
          oauth_uid
        )

        expect(subject.user_params_from_oauth_hash).to include(
          provider: oauth_provider,
          uid: oauth_uid,
          name: "Marja Mainio",
          oauth_signature: signature,
          avatar_url: nil,
          raw_data: oauth_hash
        )
      end
    end

    it_behaves_like "expected hash"

    context "when oauth data info doesnt include name" do
      let(:oauth_info) do
        {
          image: oauth_image
        }
      end
      let(:oauth_raw_info) do
        {
          name: "Marja Mirja Mainio",
          given_name: "Marja",
          family_name: "Mainio",
          national_id_num: "150785-994A",
          amr: amr
        }
      end

      it_behaves_like "expected hash"
    end

    context "when oauth data is empty" do
      let(:oauth_hash) { {} }

      it "returns nil" do
        expect(subject.user_params_from_oauth_hash).to be_nil
      end
    end

    context "when user identifier is blank" do
      let(:oauth_uid) { nil }

      it "returns nil" do
        expect(subject.user_params_from_oauth_hash).to be_nil
      end
    end
  end

  describe "#validate!" do
    it "returns true for valid authentication data" do
      expect(subject.validate!).to be(true)
    end
  end

  describe "#identify_user!" do
    let(:user) { create(:user, :confirmed, organization: organization) }

    it "creates a new identity for the user" do
      id = subject.identify_user!(user)

      expect(Decidim::Identity.count).to eq(1)
      expect(Decidim::Identity.last.id).to eq(id.id)
      expect(id.organization.id).to eq(organization.id)
      expect(id.user.id).to eq(user.id)
      expect(id.provider).to eq(oauth_provider)
      expect(id.uid).to eq(oauth_uid)
    end

    context "when an identity already exists" do
      let!(:identity) do
        user.identities.create!(
          organization: organization,
          provider: oauth_provider,
          uid: oauth_uid
        )
      end

      it "returns the same identity" do
        expect(subject.identify_user!(user).id).to eq(identity.id)
      end
    end

    # This can happen when the authentication server is changed from the legacy
    # server to the new Keycloak authentication server. An old identity will
    # exist for the legacy server and the user's `uid` will change when the
    # authentication server is swapped.
    context "when an identity already exists with another uid and matching provider" do
      let(:old_oauth_uid) { Faker::Internet.uuid }
      let!(:identity) do
        user.identities.create!(
          organization: organization,
          provider: oauth_provider,
          uid: old_oauth_uid
        )
      end

      it "returns a new identity and allows identification" do
        expect(subject.identify_user!(user).id).not_to eq(identity.id)
        expect(
          Decidim::Identity.where(organization: organization, provider: oauth_provider, user: user).count
        ).to eq(2)
      end
    end

    context "when a matching identity already exists for another user" do
      let(:another_user) { create(:user, :confirmed, organization: organization) }

      before do
        another_user.identities.create!(
          organization: organization,
          provider: oauth_provider,
          uid: oauth_uid
        )
      end

      it "raises an IdentityBoundToOtherUserError" do
        expect do
          subject.identify_user!(user)
        end.to raise_error(
          Decidim::HelsinkiProfile::Authentication::IdentityBoundToOtherUserError
        )
      end
    end
  end

  describe "#authorize_user!" do
    let(:user) { create(:user, :confirmed, organization: organization) }
    let(:signature) do
      ::Decidim::OmniauthRegistrationForm.create_signature(
        oauth_provider,
        oauth_uid
      )
    end

    it "creates a new authorization for the user" do
      auth = subject.authorize_user!(user)

      expect(Decidim::Authorization.count).to eq(1)
      expect(Decidim::Authorization.last.id).to eq(auth.id)
      expect(auth.user.id).to eq(user.id)
      expect(auth.unique_id).to eq(signature)
      expect(auth.metadata).to include(
        "name" => "#{profile[:first_name]} #{profile[:last_name]}",
        "given_name" => profile[:first_name],
        "last_name" => profile[:last_name]
      )
    end

    context "when an authorization already exists" do
      let!(:authorization) do
        Decidim::Authorization.create!(
          name: "helsinki_idp",
          user: user,
          unique_id: signature
        )
      end

      it "returns the existing authorization and updates it" do
        auth = subject.authorize_user!(user)

        expect(auth.id).to eq(authorization.id)
        expect(auth.metadata).to include(
          "name" => "#{profile[:first_name]} #{profile[:last_name]}",
          "given_name" => profile[:first_name],
          "last_name" => profile[:last_name]
        )
      end
    end

    context "when a matching authorization already exists for another user" do
      let(:another_user) { create(:user, :confirmed, organization: organization) }

      before do
        Decidim::Authorization.create!(
          name: "helsinki_idp",
          user: another_user,
          unique_id: signature
        )
      end

      it "raises an IdentityBoundToOtherUserError" do
        expect do
          subject.authorize_user!(user)
        end.to raise_error(
          Decidim::HelsinkiProfile::Authentication::AuthorizationBoundToOtherUserError
        )
      end
    end
  end
end
