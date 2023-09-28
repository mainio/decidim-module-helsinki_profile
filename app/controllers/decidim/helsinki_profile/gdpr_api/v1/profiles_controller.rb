# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module GdprApi
      module V1
        class ProfilesController < ::Decidim::HelsinkiProfile::GdprApi::ApplicationController
          # Fetch all information about the user stored within the service.
          def show
            validate_scope! :query

            serializer = GdprApi::UserSerializer.new(profile_user)
            success serializer.serialize
          end

          # Note the `?dry_run=true` parameter within the request which can be
          # used to check if the user details can be removed.
          def destroy
            validate_scope! :delete

            form = DeleteAccountForm.from_params(delete_reason: "GDPR API")
            if params[:dry_run]
              return destroy_error unless form.valid?

              return success
            end

            DestroyAccount.call(profile_user, form) do
              on(:ok) { success }
              on(:invalid) { destroy_error }
            end
          end

          private

          def destroy_error
            error(
              "CONSTRAINT",
              en: "Unable to destroy the account due to internal constraints, please contact the service maintainer.",
              fi: "Tiliä ei voida poistaa sisäisten rajoitusten takia, ota yhteyttä järjestelmän ylläpitäjään.",
              sv: "Det går inte att förstöra kontot på grund av interna begränsningar, vänligen kontakta serviceansvarig."
            )
          end
        end
      end
    end
  end
end
