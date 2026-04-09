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

        def destroy_user_identities
          target_user.identities.destroy_all
        end

        def destroy_user_group_memberships
          Decidim::UserGroupMembership.where(user: target_user).destroy_all
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
      end
    end
  end
end
