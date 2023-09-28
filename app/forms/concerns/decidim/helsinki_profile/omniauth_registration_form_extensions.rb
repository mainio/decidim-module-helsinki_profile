# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module OmniauthRegistrationFormExtensions
      extend ActiveSupport::Concern

      included do
        attribute :email_confirmed, Decidim::AttributeObject::Model::Boolean, default: true
        attribute :unconfirmed_email, String, default: nil
      end
    end
  end
end
