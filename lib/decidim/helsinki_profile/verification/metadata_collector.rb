# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Verification
      class MetadataCollector
        def initialize(raw_info)
          @raw_info = raw_info[:oauth]
          @token_info = raw_info[:token]
          @profile_info = raw_info[:profile] || {}
        end

        def metadata
          {
            service: authentication_method,
            name: full_name,
            first_name: verified_personal_info[:first_name] || profile_info[:first_name] || raw_info[:first_name] || raw_info[:given_name],
            given_name: verified_personal_info[:given_name] || raw_info[:given_name],
            last_name: verified_personal_info[:last_name] || profile_info[:last_name] || raw_info[:family_name] || raw_info[:last_name],
            ad_groups: raw_info[:ad_groups]
          }.merge(identity_metadata)
        end

        # The data collected here is needed for the following purposes:
        # - municipality
        #   * For checking the person is eligible for voting (limited
        #     municipality)
        # - postal_code
        #   * For providing the correct voting area for the person (customer
        #     request)
        # - date_of_birth
        #   * For checking the person is eligible for voting (minimum voting
        #     age)
        #   * Statistics about the voters (customer request)
        # - gender
        #   * Statistics about the voters (customer request)
        def identity_metadata
          base_data = {
            postal_code:,
            municipality: verified_personal_info[:municipality_of_residence_number],
            permanent_address: verified_personal_info[:permanent_address].present?
          }.compact

          return base_data if national_id_num.blank?

          hetu = Henkilotunnus::Hetu.new(national_id_num)
          valid_hetu = hetu.send(:valid_format?) && hetu.send(:valid_checksum?)
          return base_data unless valid_hetu

          gender =
            if hetu.gender_neutral?
              "neutral"
            else
              hetu.male? ? "m" : "f"
            end

          # `.to_s` returns an ISO 8601 formatted string (YYYY-MM-DD for dates)
          date_of_birth = hetu.date_of_birth.to_s

          base_data.merge(
            gender:,
            date_of_birth:,
            pin_digest: national_id_digest
          )
        end

        # Digested format of the person's identifier unique to the person.
        # Note that HelsinkiProfile may generate different identifiers for
        # different authentication methods for the same person.
        #
        # The "sub" referes to the OpenID subject. This is what the spec says
        # about the subject:
        #   "Locally unique and never reassigned identifier within the Issuer
        #   for the End-User, which is intended to be consumed by the Client."
        #
        # This should be always set but just in case check that it exists, e.g.
        # for the specs.
        def person_identifier_digest
          return if raw_info[:sub].blank?

          @person_identifier_digest ||= Digest::MD5.hexdigest(
            "#{raw_info[:sub]}:#{Rails.application.secrets.secret_key_base}"
          )
        end

        # The national ID digest that identifies the same person across
        # different ways of authentication (e.g. assisted votings). This allows
        # us to limit e.g. PB voting to a specific person, no matter how they
        # identified to the service, digitally or physically.
        #
        # This digest (i.e. pseudonymized format) is stored against the
        # authorization record in order to make it searchable because searching
        # through the encrypted metadata of thousands of people would be
        # extremely slow and completely unusable.
        def national_id_digest
          return if national_id_num.blank?

          @national_id_digest ||= Digest::MD5.hexdigest(
            "FI:#{national_id_num}:#{Rails.application.secrets.secret_key_base}"
          )
        end

        protected

        attr_reader :raw_info, :token_info, :profile_info

        # One of following:
        # - suomi_fi
        # - heltunnistus_suomi_fi
        def authentication_method
          # Authentication Method Reference (amr)
          Array(token_info[:amr]).compact.presence
        end

        def full_name
          if verified_personal_info.present?
            parts = [:first_name, :last_name].map { |key| verified_personal_info[key] }.compact
            return parts.join(" ") unless parts.empty?
          end

          raw_info[:name]
        end

        def national_id_num
          verified_personal_info[:national_identification_number] || raw_info[:national_id_num]
        end

        def verified_personal_info
          profile_info[:verified_personal_information] || {}
        end

        def postal_code
          return unless verified_personal_info[:permanent_address]

          verified_personal_info[:permanent_address][:postal_code]
        end
      end
    end
  end
end
