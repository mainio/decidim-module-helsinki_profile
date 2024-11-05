# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module CreateOmniauthRegistrationOverride
      extend ActiveSupport::Concern

      included do
        private

        alias_method :create_or_find_user_orig_helsinki, :create_or_find_user unless private_method_defined?(:create_or_find_user_orig_helsinki)

        def create_or_find_user
          create_or_find_user_orig_helsinki
          return if form.email_confirmed?
          return if another_user_reserved_email?(form.unconfirmed_email)

          @user.unconfirmed_email = form.unconfirmed_email if form.unconfirmed_email.present?
          @user.save!
        end

        def another_user_reserved_email?(email)
          Decidim::User.unscoped.where.not(id: @user.id).exists?(
            organization:,
            email:
          )
        end
      end
    end
  end
end
