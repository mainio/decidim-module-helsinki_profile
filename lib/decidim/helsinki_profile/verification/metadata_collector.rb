# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Verification
      class MetadataCollector
        def initialize(raw_info)
          @raw_info = raw_info
        end

        def metadata
          {
            service: authentication_method,
            name: raw_info[:name],
            first_name: raw_info[:first_name] || raw_info[:given_name],
            given_name: raw_info[:given_name],
            family_name: raw_info[:family_name] || raw_info[:last_name],
            ad_groups: raw_info[:ad_groups]
          }.merge(identity_metadata)
        end

        # Note: for the time being, the identity metadata is missing
        # municipality and postal code information at this point since this data
        # does not seem to be available. However, this would be eventually
        # needed in order to verify that only people from a certain municipality
        # can vote.
        #
        # The other data collected here is needed for the following purposes:
        # - date_of_birth
        #   * For checking the person is eligible for voting (minimum voting
        #     age)
        #   * Statistics about the voters (customer request)
        # - gender
        #   * Statistics about the voters (customer request)
        def identity_metadata
          return {} if national_id_num.blank?

          hetu = Henkilotunnus::Hetu.new(national_id_num)
          valid_hetu = hetu.send(:valid_format?) && hetu.send(:valid_checksum?)
          return {} unless valid_hetu

          gender =
            if hetu.gender_neutral?
              "neutral"
            else
              hetu.male? ? "m" : "f"
            end

          # `.to_s` returns an ISO 8601 formatted string (YYYY-MM-DD for dates)
          date_of_birth = hetu.date_of_birth.to_s

          {
            gender: gender,
            date_of_birth: date_of_birth,
            pin_digest: national_id_digest
          }
        end

        # Digested format of the person's identifier unique to the person.
        # Note that HelsinkiProfile may generate different identifiers for
        # different authentication methods for the same person.
        #
        # The "sub" referes to the OpenID subject. This is what the spec says
        # about the subject:
        #   "Locally unique and never reassigned identifier within the Issuer
        #   for the End-User, which is intended to be consumed by the Client."
        def person_identifier_digest
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

        attr_reader :raw_info

        # One of following:
        # - suomi_fi
        # - heltunnistus_suomi_fi
        def authentication_method
          # Authentication Method Reference (amr)
          Array(raw_info[:amr]).compact.presence
        end

        def national_id_num
          raw_info[:national_id_num]
        end
      end
    end
  end
end
