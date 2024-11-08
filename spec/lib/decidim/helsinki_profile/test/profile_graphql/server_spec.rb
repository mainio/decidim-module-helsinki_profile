# frozen_string_literal: true

require "spec_helper"

# Tests for the dummy profile API that it is responding with the expected
# messages. In case this is broken, it may affect other code which is why this
# has basic tests to ensure it is functioning correctly.
#
# For actual use, the profile API is served by the Helsinki servers.
describe Decidim::HelsinkiProfile::Test::ProfileGraphql::Server do
  let(:auth_server) { Decidim::HelsinkiProfile::Test::OidcServer.get(:auth) }
  let(:auth_token) { auth_server.token(sub: profile[:id]) }
  let(:mock_response) { MockResponse.new }
  let(:response) do
    Net::HTTP.post(
      URI.parse(described_class.instance.uri),
      { query: "{ #{query} }" }.to_json,
      "Authorization" => "Bearer #{auth_token}",
      "Content-Type": "application/json"
    )
  end
  let(:response_json) { JSON.parse(response.body) }
  let(:response_data) { response_json["data"] }
  let(:response_errors) { response_json["errors"] }

  let(:profile) { create(:helsinki_profile_person) }
  let(:profile_api) { Decidim::HelsinkiProfile::Test::ProfileGraphql::Server.instance }

  let(:query) { "myProfile { id firstName }" }

  before do
    profile_api.register_profile(profile)
  end

  it "runs the GraphQL query" do
    expect(mock_response.status(response)).to eq(200)
    expect(response_data).to eq(
      "myProfile" => { "id" => profile[:id], "firstName" => profile[:first_name] }
    )
    expect(response_errors).to be_nil
  end

  context "with verifiedPersonalInformation" do
    let(:query) { "myProfile { verifiedPersonalInformation { firstName } }" }

    it "runs the GraphQL query" do
      expect(mock_response.status(response)).to eq(200)
      expect(response_data).to eq(
        "myProfile" => { "verifiedPersonalInformation" => { "firstName" => profile[:first_name] } }
      )
      expect(response_errors).to be_nil
    end

    context "when access is not permitted" do
      before do
        profile_api.set_permission(:verified_information, false)
      end

      it "returns an error" do
        expect(mock_response.status(response)).to eq(200)
        expect(response_data).to eq(
          "myProfile" => { "verifiedPersonalInformation" => nil }
        )
        expect(response_errors).to eq(
          [
            {
              "message" => "You do not have permission to perform this action.",
              "locations" => [{ "line" => 1, "column" => 15 }],
              "path" => %w(myProfile verifiedPersonalInformation),
              "extensions" => { "code" => "PERMISSION_DENIED_ERROR" }
            }
          ]
        )
      end
    end
  end

  context "when the auth token is incorrect" do
    let(:auth_token) { "foobar" }

    it "returns errors" do
      expect(mock_response.status(response)).to eq(200)
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

  class MockResponse
    def status(response)
      response.code.to_i
    end

    def body(response)
      response.body
    end
  end
end
