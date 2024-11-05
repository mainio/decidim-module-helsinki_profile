# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module GdprApi
      # Turns the Decidim export format into the GDPR API defined format.
      class UserSerializer
        def initialize(user)
          @user = user
        end

        def serialize
          (
            [user_data, authorization_data] +
            DownloadYourDataSerializers.data_entities.map do |entity|
              # The user export is handled separately with the `user_data`
              # method because otherwise it would be exported as an array.
              next if entity == "Decidim::User"

              klass = Object.const_get(entity)
              export(klass)
            end
          ).compact
        end

        private

        attr_reader :user

        def user_data
          data = export(Decidim::User)
          data[:children].first
        end

        def authorization_data
          authorization = Authorization.find_by(user:, name: "helsinki_idp")
          return unless authorization
          return unless authorization.granted?
          return if authorization.expired?

          metadata = authorization.metadata
          data = [:gender, :date_of_birth, :postal_code, :municipality].index_with { |key| metadata[key.to_s] }.compact
          return if data.blank?

          export_value("authorization", data)
        end

        def export(klass)
          name = klass.model_name.name.parameterize.sub(/^decidim-/, "")
          data = klass.user_collection(user).order(:id).map do |item|
            klass.export_serializer.new(item).serialize
          end
          collection = export_value(name, data)
          return if collection[:children].empty?

          collection
        end

        def export_value(key, value, record: false)
          if value.is_a?(Enumerable)
            children =
              if value.is_a?(Array)
                value.map do |v|
                  export_value(key, v, record: true)
                end
              else
                value.map do |k, v|
                  export_value(k, v)
                end
              end
            name = record ? key.to_s : key.to_s.pluralize
            { name: name.upcase, children: }
          else
            { key: key.to_s.upcase, value: }
          end
        end
      end
    end
  end
end
