# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Authentication
      class Authenticator
        include ActiveModel::Validations

        def initialize(organization, oauth_hash)
          @organization = organization
          @oauth_hash = oauth_hash
        end

        def verified_email
          @verified_email ||=
            if email_confirmed?
              digged_email || generate_email
            else
              generate_email
            end
        end

        def digged_email
          @digged_email ||= oauth_data.dig(:info, :email)
        end

        # Private: Create form params from omniauth hash
        # Since we are using trusted omniauth data we are generating a valid signature.
        def user_params_from_oauth_hash
          return nil if oauth_data.empty?
          return nil if user_identifier.blank?

          {
            provider: oauth_data[:provider],
            uid: user_identifier,
            name: user_full_name,
            email_confirmed: email_confirmed?,
            unconfirmed_email: digged_email,
            # The nickname is automatically "parametrized" by Decidim core from
            # the name string, i.e. it will be in correct format.
            nickname: oauth_nickname,
            oauth_signature: user_signature,
            avatar_url: oauth_data[:info][:image],
            raw_data: oauth_hash
          }
        end

        def validate!
          raise ValidationError, "Invalid person dentifier" if person_identifier_digest.blank?

          true
        end

        def identify_user!(user)
          identity = user.identities.find_by(
            organization: organization,
            provider: oauth_data[:provider],
            uid: user_identifier
          )
          return identity if identity

          # Check that the identity is not already bound to another user.
          id = Decidim::Identity.find_by(
            organization: organization,
            provider: oauth_data[:provider],
            uid: user_identifier
          )

          raise IdentityBoundToOtherUserError if id

          user.identities.create!(
            organization: organization,
            provider: oauth_data[:provider],
            uid: user_identifier
          )
        end

        def authorize_user!(user)
          authorization = Decidim::Authorization.find_by(
            name: "helsinki_idp",
            unique_id: user_signature
          )
          if authorization
            raise AuthorizationBoundToOtherUserError if authorization.user != user
          else
            authorization = Decidim::Authorization.find_or_initialize_by(
              name: "helsinki_idp",
              user: user
            )
          end

          authorization.pseudonymized_pin = national_id_digest if authorization.pseudonymized_pin.blank? && national_id_digest.present?
          authorization.attributes = {
            unique_id: user_signature,
            metadata: authorization_metadata
          }
          authorization.save!

          # This will update the "granted_at" timestamp of the authorization which
          # will postpone expiration on re-authorizations in case the
          # authorization is set to expire (by default it will not expire).
          authorization.grant!

          authorization
        end

        def email_confirmed?
          return false if untrusted_email_provider?

          oauth_raw_info[:email_verified] && digged_email.present?
        end

        def untrusted_email_provider?
          untrusted_email_providers = Decidim::HelsinkiProfile.untrusted_email_providers
          return false if untrusted_email_providers.blank?
          return false if authentication_service.blank?

          untrusted_email_providers.any? { |provider| authentication_service.include?(provider) }
        end

        protected

        attr_reader :organization, :oauth_hash

        def generate_email
          @generate_email ||= begin
            domain = Decidim::HelsinkiProfile.auto_email_domain || organization.host
            "helsinki-#{person_identifier_digest}@#{domain}"
          end
        end

        def oauth_data
          @oauth_data ||= oauth_hash.slice(:provider, :uid, :info)
        end

        # The HelsinkiProfile's assigned UID for the person.
        def user_identifier
          @user_identifier ||= oauth_data[:uid]
        end

        def authentication_service
          @authentication_service ||= Array(oauth_raw_info[:amr]).compact
        end

        # Create a unique signature for the user that will be used for the
        # granted authorization.
        def user_signature
          @user_signature ||= ::Decidim::OmniauthRegistrationForm.create_signature(
            oauth_data[:provider],
            user_identifier
          )
        end

        def user_full_name
          return oauth_data[:info][:name] if oauth_data[:info][:name]

          @user_full_name ||= begin
            first_name = oauth_raw_info[:given_name] || oauth_raw_info[:first_name]
            last_name = oauth_raw_info[:last_name] || oauth_raw_info[:family_name]

            "#{first_name} #{last_name}"
          end
        end

        def oauth_name
          oauth_data.dig(:info, :name) || oauth_nickname || verified_email.split("@").first
        end

        def oauth_nickname
          # Fetch the nickname passed form HelsinkiProfile
          oauth_data.dig(:info, :nickname) || oauth_raw_info[:nickname]
        end

        def metadata_collector
          @metadata_collector ||= Decidim::HelsinkiProfile::Verification::Manager.metadata_collector_for(
            oauth_raw_info
          )
        end

        # Data that is stored against the authorization "permanently" (i.e. as
        # long as the authorization is valid).
        def authorization_metadata
          metadata_collector.metadata
        end

        # The digest that is created from the person identifier (OpenID sub).
        def person_identifier_digest
          metadata_collector.person_identifier_digest
        end

        def national_id_digest
          metadata_collector.national_id_digest
        end

        def oauth_raw_info
          oauth_hash.dig(:extra, :raw_info) || {}
        end
      end
    end
  end
end
