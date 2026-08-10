# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module DestroyAccountExtensions
      extend ActiveSupport::Concern

      included do
        def initialize(form, target_user: nil)
          @form = form
          @target_user = target_user || current_user
        end

        private

        attr_reader :form, :target_user

        def destroy_user_account!
          target_user.invalidate_all_sessions!

          target_user.name = ""
          target_user.nickname = ""
          target_user.email = ""
          target_user.personal_url = ""
          target_user.about = ""
          target_user.notifications_sending_frequency = "none"
          target_user.delete_reason = @form.delete_reason
          target_user.admin = false if target_user.admin?
          target_user.deleted_at = Time.current
          target_user.skip_reconfirmation!
          target_user.avatar.purge
          target_user.save!
        end

        def destroy_user_badges
          Decidim::Gamification::BadgeScore.where(user: target_user).find_each(&:destroy)
        end

        def destroy_user_reports
          Decidim::UserModeration.where(user: target_user).find_each(&:destroy)
        end

        def destroy_user_likes
          Decidim::Like.where(author: target_user).find_each(&:destroy)
        end

        def destroy_user_identities
          target_user.identities.find_each(&:destroy)
        end

        def destroy_user_versions
          target_user.versions.find_each(&:destroy)
        end

        def destroy_user_private_exports
          target_user.private_exports.find_each(&:destroy)
        end

        def destroy_user_access_grants
          target_user.access_grants.find_each(&:destroy)
        end

        def destroy_user_access_tokens
          target_user.access_tokens.find_each(&:destroy)
        end

        def destroy_user_reminders
          target_user.reminders.find_each(&:destroy)
        end

        def destroy_user_notifications
          target_user.notifications.find_each(&:destroy)
        end

        def destroy_follows
          Decidim::Follow.where(followable: target_user).destroy_all
          Decidim::Follow.where(user: target_user).destroy_all
        end

        def destroy_participatory_space_private_user
          Decidim::ParticipatorySpacePrivateUser.where(user: target_user).destroy_all
        end

        def delegate_destroy_to_participatory_spaces
          Decidim.participatory_space_manifests.each do |space_manifest|
            space_manifest.invoke_on_destroy_account(target_user)
          end
        end

        # We use memoization in this particular email, as we want to have the data available before the actual anonymization
        def event_arguments
          @event_arguments ||= {
            user_id: target_user.id,
            user_email: target_user.email,
            user_name: target_user.name,
            locale: target_user.locale,
            organization: target_user.organization
          }
        end
      end
    end
  end
end
