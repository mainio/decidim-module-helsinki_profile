# frozen_string_literal: true

module HelsinkiProfileFactoryHelpers
  def country_to_locale(country)
    case country
    when "FI"
      "fi-FI"
    else
      "en"
    end
  end

  def municipality_code(municipality_name)
    case municipality_name
    when "Helsinki"
      "091"
    else
      num = nil
      num = rand(4..999) while num.nil? || num == 91
      num.to_s.rjust(3, "0")
    end
  end
end

FactoryBot::SyntaxRunner.include(HelsinkiProfileFactoryHelpers)

FactoryBot.define do
  factory :helsinki_profile_data, class: Hash do
    transient do
      country_code { "FI" }
      locale { country_to_locale(country_code) }
    end

    skip_create
    initialize_with do
      Faker::Base.with_locale(locale) do
        attributes
      end
    end
  end

  factory :helsinki_profile_person, parent: :helsinki_profile_data do
    transient do
      city { "Helsinki" }

      # DOMESTIC_PERMANENT, DOMESTIC_TEMPORARY, FOREIGN_PERMANENT
      address_type { "DOMESTIC_PERMANENT" }
    end

    id { Faker::Internet.uuid }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    nickname { generate(:nickname) }
    language { "fi" }
    primary_email { create(:helsinki_profile_email, :primary) }
    primary_address { create(:helsinki_profile_address, :primary, locale: locale, city: city, country_code: country_code) }
    verified_personal_information do
      create(
        :helsinki_profile_personal_info,
        municipality_of_residence: city,
        country_code: country_code,
        address: primary_address,
        address_type: address_type,
        locale: locale,
        first_name: first_name,
        last_name: last_name,
        given_name: first_name
      )
    end
  end

  factory :helsinki_profile_email, parent: :helsinki_profile_data do
    id { Faker::Internet.uuid }
    primary { false }
    email { Faker::Internet.email }
    email_type { %w(NONE WORK PERSONAL OTHER).sample }
    verified { true }

    trait :primary do
      primary { true }
    end

    trait :unverified do
      verified { false }
    end
  end

  factory :helsinki_profile_personal_info, parent: :helsinki_profile_data do
    transient do
      # DOMESTIC_PERMANENT, DOMESTIC_TEMPORARY, FOREIGN_PERMANENT
      address_type { "DOMESTIC_PERMANENT" }
      address do
        traits = [:primary]
        traits << :foreign if address_type == "FOREIGN_PERMANENT"
        create(
          :helsinki_profile_address,
          *traits,
          city: municipality_of_residence,
          country_code: country_code,
          locale: locale
        )
      end
    end

    first_name { Faker::Name.first_name }
    last_name { Faker::Name.first_name }
    given_name { Faker::Name.first_name }
    national_identification_number { Henkilotunnus::Hetu.generate.pin }
    municipality_of_residence { "Helsinki" }
    municipality_of_residence_number { municipality_code(municipality_of_residence) }
    permanent_address { nil }
    temporary_address { nil }
    permanent_foreign_address { nil }

    before(:create) do |object, evaluator|
      if [:permanent_address, :temporary_address, :permanent_foreign_address].all? { |key| object[key].blank? }
        case evaluator.address_type
        when "DOMESTIC_TEMPORARY"
          object[:temporary_address] = evaluator.address
        when "FOREIGN_PERMANENT"
          object[:permanent_foreign_address] = evaluator.address
        else # DOMESTIC_PERMANENT
          object[:permanent_address] = evaluator.address
        end
      end
    end
  end

  factory :helsinki_profile_address, parent: :helsinki_profile_data do
    transient do
      locale { country_to_locale(country_code) }
    end

    id { Faker::Internet.uuid }
    primary { false }
    address { Faker::Address.street_address }
    postal_code { Faker::Address.zip_code }
    city { Faker::Address.city }
    country_code { "FI" }
    address_type { %w(NONE WORK HOME OTHER).sample }

    trait :primary do
      primary { true }
    end

    trait :foreign do
      country_code { Faker::Address.country_code }
    end
  end
end
