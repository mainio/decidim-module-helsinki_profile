# frozen_string_literal: true

require "spec_helper"

describe Decidim::HelsinkiProfile::GdprApi::V1::ProfilesController do
  routes { Decidim::HelsinkiProfile::Engine.routes }

  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }
  let!(:identity) { create(:identity, user:, provider: "helsinki", uid: identity_uid) }
  let!(:authorization) do
    create(
      :authorization,
      user:,
      name: "helsinki_idp",
      unique_id: authorization_unique_id,
      pseudonymized_pin:,
      metadata: authorization_metadata,
      granted_at: authorization_granted_at
    )
  end
  let(:identity_uid) do
    Decidim::OmniauthRegistrationForm.create_signature(
      "helsinki",
      profile_uuid
    )
  end
  let(:profile_uuid) { "60f03ffc-d02a-47b1-8315-395a37a9b4a0" }
  let(:authorization_granted_at) { 1.week.ago }
  let(:authorization_unique_id) { "123456" }
  let(:authorization_metadata) do
    {
      gender: "m",
      date_of_birth: "2001-04-01",
      postal_code: "00210",
      municipality: "091",
      pin_digest: pseudonymized_pin
    }
  end
  let(:pseudonymized_pin) do
    Digest::MD5.hexdigest("FI:010400A901X:#{Rails.application.secrets.secret_key_base}")
  end
  let(:jwt) { oidc_server.jwt({ aud: gdpr_audience, sub: profile_uuid, scope: gdpr_scopes }.merge(jwt_payload)).sign(jwt_key) }
  let(:gdpr_audience) { Decidim::HelsinkiProfile.omniauth_secrets[:gdpr_client_id] }
  let(:gdpr_scopes) { Decidim::HelsinkiProfile.gdpr_scopes.values.join(" ") }
  let(:jwt_payload) { {} }
  let(:jwt_key) do
    # We need to issue the same kid for the JSON::JWK key as the server keys
    # that are generated through JWT::JWK. We use JSON::JWK in the specs to
    # control better the signing of the keys.
    JSON::JWK.new(oidc_server.jwk_rsa_keys.first, kid: oidc_server.jwks.first.kid)
  end
  let(:oidc_server) { Decidim::HelsinkiProfile::Test::OidcServer.get(:auth) }

  before do
    request.env["decidim.current_organization"] = organization
  end

  shared_examples "valid authorization" do |response_code|
    let!(:data) { nil }

    before do
      request.headers["Authorization"] = "Bearer #{jwt}"
      perform_request
    end

    it "responds with '#{response_code}'" do
      expect(response).to have_http_status(response_code)
    end

    context "when using another valid signing key" do
      let(:jwt_key) { JSON::JWK.new(oidc_server.jwk_rsa_keys.last, kid: oidc_server.jwks.keys.last.kid) }

      it "responds with '#{response_code}'" do
        expect(response).to have_http_status(response_code)
      end
    end

    context "when the token signature is not identified by kid" do
      let(:jwt_key) { oidc_server.jwk_rsa_keys.first }

      it "responds with '#{response_code}'" do
        expect(response).to have_http_status(response_code)
      end
    end

    context "when the scope is provided as an array" do
      let(:gdpr_scopes) { Decidim::HelsinkiProfile.gdpr_scopes.values }

      it "responds with '#{response_code}'" do
        expect(response).to have_http_status(response_code)
      end
    end

    context "when the token is signed with the client secret" do
      let(:jwt_key) { Decidim::HelsinkiProfile.omniauth_secrets[:gdpr_client_secret] }

      [:HS256, :HS384, :HS512].each do |alg|
        context "with #{alg}" do
          let(:jwt) { oidc_server.jwt(aud: gdpr_audience, sub: profile_uuid, scope: gdpr_scopes).sign(jwt_key, alg) }

          it "responds with '#{response_code}'" do
            expect(response).to have_http_status(response_code)
          end
        end
      end
    end

    context "when the identity does not exist" do
      let!(:identity) { nil }

      it "responds with 404" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the user is deleted" do
      let(:user) { create(:user, :deleted, :confirmed, organization:) }

      it "responds with 404" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the user belongs to another organization" do
      let(:another_organization) { create(:organization) }
      let(:user) { create(:user, :confirmed, organization: another_organization) }

      it "responds with 404" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  shared_examples "invalid authorization" do
    context "without authorization" do
      before { perform_request }

      it "responds with 401" do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with authorization" do
      before do
        request.headers["Authorization"] = "Bearer #{jwt}"
        perform_request
      end

      context "when the token is incorrectly formatted" do
        let(:jwt) { "foobar" }

        it "responds with 401" do
          expect(response).to have_http_status(:unauthorized)
        end

        context "and has three parts" do
          let(:jwt) { "foo.bar.baz" }

          it "responds with 401" do
            expect(response).to have_http_status(:unauthorized)
          end
        end
      end

      context "when the token is signed with invalid key" do
        let(:jwt_key) { JSON::JWK.new(OpenSSL::PKey::RSA.new(2048)) }

        it "responds with 401" do
          expect(response).to have_http_status(:unauthorized)
        end

        context "and the token signature is not identified with kid" do
          let(:jwt_key) { OpenSSL::PKey::RSA.new(2048) }

          it "responds with 401" do
            expect(response).to have_http_status(:unauthorized)
          end
        end
      end

      context "when the token is signed with incorrect client secret" do
        let(:jwt_key) { "foobar" }

        [:HS256, :HS384, :HS512].each do |alg|
          context "with #{alg}" do
            let(:jwt) { oidc_server.jwt(aud: gdpr_audience, sub: profile_uuid, scope: gdpr_scopes).sign(jwt_key, alg) }

            it "responds with 401" do
              expect(response).to have_http_status(:unauthorized)
            end
          end
        end
      end

      context "when the iss claim does not match" do
        let(:jwt_payload) { { iss: "https://anotheroidc.example.org/auth" } }

        it "responds with 401" do
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the aud claim does not match" do
        let(:jwt_payload) { { aud: "foobar" } }

        it "responds with 401" do
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the sub claim does not match" do
        let(:jwt_payload) { { sub: "11111111-2222-3333-4444-555555555555" } }

        it "responds with 401" do
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the token has expired" do
        let(:jwt_payload) { { iat: 1.hour.ago } }

        it "responds with 401" do
          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when the requested scope has not been granted" do
        let(:jwt_payload) { { scope: "foo bar" } }

        it "responds with 401" do
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  describe "GET show" do
    it_behaves_like "valid authorization", :ok do
      let(:user_data) { response.parsed_body }

      it "contains the user information" do
        expect(user_data).to include(export_record(user))
      end

      it "contains the authorization" do
        expect(user_data).to include(
          export_value(
            "authorization",
            authorization_metadata.except(:pin_digest)
          )
        )
      end

      it "contains the identities" do
        expect(user_data).to include(
          "name" => "IDENTITIES",
          "children" => [export_record(identity)]
        )
      end

      context "with comments" do
        let(:component) { create(:dummy_component, organization:) }
        let(:commentable) { create(:dummy_resource, :published, component:) }
        let(:user_comments) { create_list(:comment, 5, author: user, commentable:) }
        let(:other_comments) { create_list(:comment, 10, commentable:) }

        let!(:data) { user_comments && other_comments }

        it "contains the comments" do
          # In order to avoid inconsistencies with the data, fetch the records
          # the same way as the exporter does.
          comments = Decidim::Comments::Comment.where(id: user_comments).order(:id).map { |c| export_record(c) }

          expect(user_data).to include(
            "name" => "COMMENTS-COMMENTS",
            "children" => comments
          )
        end
      end

      context "with proposals" do
        let(:component) { create(:proposal_component, organization:) }
        let(:user_proposals) { create_list(:proposal, 5, users: [user], component:) }
        let(:other_proposals) { create_list(:proposal, 10, component:) }

        let!(:data) { user_proposals && other_proposals }

        it "contains the proposals" do
          # In order to avoid inconsistencies with the data, fetch the records
          # the same way as the exporter does.
          proposals = Decidim::Proposals::Proposal.where(id: user_proposals).order(:id).map { |c| export_record(c) }

          expect(user_data).to include(
            "name" => "PROPOSALS-PROPOSALS",
            "children" => proposals
          )
        end
      end

      def export_record(record)
        name = record.class.model_name.name.parameterize.sub(/^decidim-/, "")
        export_value(
          name,
          record.class.export_serializer.new(record).serialize,
          record: true
        )
      end

      def export_value(key, value, record: false)
        if value.is_a?(Enumerable)
          children =
            if value.is_a?(Array)
              value.map do |v|
                export_value(key, v, record: true)
              end
            else
              value.map do |k, v|
                export_value(k, v)
              end
            end
          name = record ? key.to_s : key.to_s.pluralize
          { "name" => name.upcase, "children" => children }
        else
          exported_value = value.is_a?(Time) ? value.iso8601(3) : value
          { "key" => key.to_s.upcase, "value" => exported_value }
        end
      end
    end

    it_behaves_like "invalid authorization"

    def perform_request
      get :show, params: { uuid: profile_uuid }
    end
  end

  describe "DELETE destroy" do
    it_behaves_like "valid authorization", :no_content do
      it "destroys the user account" do
        expect(user.reload.deleted?).to be(true)
      end
    end

    it_behaves_like "invalid authorization"

    def perform_request
      delete :destroy, params: { uuid: profile_uuid }
    end
  end
end
