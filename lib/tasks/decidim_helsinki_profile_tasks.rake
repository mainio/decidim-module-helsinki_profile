# frozen_string_literal: true

namespace :decidim do
  namespace :helsinki_profile do
    desc "Creates a test user for the GDPR API tester"
    task :create_test_user, [:organization_id, :uuid, :email] => :environment do |_t, args|
      organization = Decidim::Organization.find(args.organization_id)

      uid_signature = Decidim::OmniauthRegistrationForm.create_signature("helsinki", args.uuid)
      identity = Decidim::Identity.find_by(
        # Unscoped needed for this to work with the privacy module
        user: Decidim::User.unscoped.where(organization: organization),
        provider: "helsinki",
        uid: uid_signature
      )
      user = identity.user if identity
      user ||= Decidim::User.unscoped.find_by(organization: organization, email: args.email)
      user ||= Decidim::User.create!(
        organization: organization,
        email: args.email,
        nickname: Decidim::UserBaseEntity.nicknamize("helsinkiprofile_test", organization: organization),
        name: "Terry Testing",
        password: "decidim123456789",
        password_confirmation: "decidim123456789",
        tos_agreement: true,
        accepted_tos_version: organization.tos_version,
        locale: organization.available_locales.first,
        confirmed_at: Time.current
      )
      unless identity
        user.identities.create!(
          organization: organization,
          provider: "helsinki",
          uid: uid_signature
        )
      end

      authorization = Decidim::Authorization.find_by(
        name: "helsinki_idp",
        unique_id: uid_signature
      )
      unless authorization
        national_id_num = Henkilotunnus::Hetu.generate.pin
        national_id_digest = Digest::MD5.hexdigest(
          "FI:#{national_id_num}:#{Rails.application.secrets.secret_key_base}"
        )
        hetu = Henkilotunnus::Hetu.new(national_id_num)

        Decidim::Authorization.create!(
          name: "helsinki_idp",
          user: user,
          unique_id: uid_signature,
          pseudonymized_pin: national_id_digest,
          granted_at: Time.current,
          metadata: {
            service: ["suomi_fi"],
            name: "Terry Testing",
            first_name: "Terry Test",
            given_name: "Terry",
            last_name: "Testing",
            ad_groups: nil,
            postal_code: "00210",
            municipality: "091",
            permanent_address: true,
            gender:
              if hetu.gender_neutral?
                "neutral"
              else
                hetu.male? ? "m" : "f"
              end,
            date_of_birth: hetu.date_of_birth.to_s,
            pin_digest: national_id_digest
          }
        )
      end
    end
  end
end
