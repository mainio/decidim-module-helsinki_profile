# frozen_string_literal: true

require "spec_helper"

describe Decidim::HelsinkiProfile::GdprApi::Client do
  let(:client) { described_class.new(access_token) }
  let(:auth_server) { Decidim::HelsinkiProfile::Test::OidcServer.get(:auth) }
  let(:access_token) do
    auth_server.token(
      scope: Decidim::HelsinkiProfile.omniauth_secrets[:gdpr_uri],
      sub: profile[:id]
    )
  end

  let(:profile) { create(:helsinki_profile_person) }
  let(:gdpr_api) { Decidim::HelsinkiProfile::Test::GdprGraphql::Server.instance }

  before do
    gdpr_api.register_profile(profile)
  end

  describe "#fetch" do
    subject { client.fetch }

    it "returns the authenticated user data for the token" do
      # The returned data is a subset of the whole profile which is why this
      # compares the exact data we are expecting to get from the GDPR client.
      expect(subject).to eq(
        first_name: profile[:first_name],
        last_name: profile[:last_name],
        nickname: profile[:nickname],
        primary_email: {
          email: profile[:primary_email][:email],
          verified: profile[:primary_email][:verified]
        },
        verified_personal_information: {
          first_name: profile[:verified_personal_information][:first_name],
          given_name: profile[:verified_personal_information][:given_name],
          last_name: profile[:verified_personal_information][:last_name],
          national_identification_number: profile[:verified_personal_information][:national_identification_number],
          municipality_of_residence_number: profile[:verified_personal_information][:municipality_of_residence_number],
          permanent_address: {
            postal_code: profile[:verified_personal_information][:permanent_address][:postal_code]
          }
        }
      )
    end
  end
end
