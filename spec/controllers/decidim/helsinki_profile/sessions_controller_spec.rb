# frozen_string_literal: true

require "spec_helper"

describe Decidim::HelsinkiProfile::SessionsController, type: :request do
  let(:organization) { create(:organization) }
  let(:id_token) { "stored_id_token" }
  let!(:current_user) { create(:user, :confirmed, organization: organization) }
  let!(:session_info) do
    Decidim::HelsinkiProfile::SessionInfo.create(user: current_user, id_token: id_token)
  end

  let(:session) { { "decidim-helsinkiprofile.signed_in" => true } }
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

  before do
    # Set the correct host
    host! organization.host

    # Initiate the current user session
    sign_in current_user
    get("/")
  end

  describe "POST destroy" do
    it "goes through correct controller" do
      post("/users/sign_out", **request_args)
      expect(controller).to be_a(described_class)
    end

    it "destroys the user session" do
      expect(controller.current_user).to eq(current_user)

      post("/users/sign_out", **request_args)
      expect(controller.current_user).to be_nil
    end

    it "adds the id_token_hint parameter to the logout request" do
      post("/users/sign_out", **request_args)

      expect(response).to redirect_to("/users/auth/helsinki/logout?id_token_hint=#{id_token}")
    end

    it "destroys the session info" do
      expect { post("/users/sign_out", **request_args) }.to change(Decidim::HelsinkiProfile::SessionInfo, :count).by(-1)

      expect(Decidim::HelsinkiProfile::SessionInfo.find_by(id: session_info.id)).to be_nil
    end
  end
end
