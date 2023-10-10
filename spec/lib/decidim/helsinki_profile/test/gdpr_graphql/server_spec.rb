# frozen_string_literal: true

require "spec_helper"

# Tests for the dummy GDPR API that it is responding with the expected messages.
# In case this is broken, it may affect other code which is why this has basic
# tests to ensure it is functioning correctly.
#
# For actual use, the GDPR API is served by the Helsinki servers.
describe Decidim::HelsinkiProfile::Test::GdprGraphql::Server do
  let(:gdpr_server) { Decidim::HelsinkiProfile::Test::OidcServer.get(:gdpr) }
  let(:auth_token) { gdpr_server.token(sub: profile[:id]) }
  let(:response) do
    Net::HTTP.post(
      URI.parse("https://gdpr.example.org/graphql"),
      "{ #{query} }",
      "Authorization" => "Bearer #{auth_token}"
    )
  end
  let(:response_json) { JSON.parse(response.body) }
  let(:response_data) { response_json["data"] }
  let(:response_errors) { response_json["errors"] }

  let(:profile) { create(:helsinki_profile_person) }
  let(:gdpr_api) { Decidim::HelsinkiProfile::Test::GdprGraphql::Server.instance }

  let(:query) { "myProfile { id firstName }" }

  before do
    gdpr_api.register_profile(profile)
  end

  it "runs the GDPR query" do
    expect(response.code).to eq("200")
    expect(response_data).to eq(
      "myProfile" => { "id" => profile[:id], "firstName" => profile[:first_name] }
    )
  end

  context "when the auth token is incorrect" do
    let(:auth_token) { "foobar" }

    it "returns errors" do
      expect(response.code).to eq("200")
      expect(response_data).to eq("myProfile" => nil)
      expect(response_errors).to eq(
        [
          {
            "message" => "You do not have permission to perform this action.",
            "locations" => [{ "line" => 1, "column" => 3 }],
            "path" => ["myProfile"],
            "extensions" => { "code" => "PERMISSION_DENIED_ERROR" }
          }
        ]
      )
    end
  end
end
