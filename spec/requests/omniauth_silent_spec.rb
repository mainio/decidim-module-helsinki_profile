# frozen_string_literal: true

require "spec_helper"

describe "OmniAuth silent", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization: organization) }

  let(:oauth_hash) do
    {
      provider: "helsinki"
    }
  end

  before do
    # Set the correct host
    host! organization.host
  end

  describe "GET /users/auth/helsinki/silent" do
    it "makes a call to the server" do
      sign_in user
      get("/users/auth/helsinki/silent")

      expect(response).to redirect_to(%r{\Ahttps://oicd.example.org/auth/realms/helsinki-tunnistus/protocol/openid-connect/auth})

      uri = URI.parse(response.headers["Location"])
      query = uri.query.split("&")
      expect(query).to include("prompt=none")
    end
  end
end
