# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Verification
      # This is an engine that performs user authorization.
      class Engine < ::Rails::Engine
        isolate_namespace Decidim::HelsinkiProfile::Verification

        paths["db/migrate"] = nil
        paths["lib/tasks"] = nil

        routes do
          resource :authorizations, only: [:new], as: :authorization

          root to: "authorizations#new"
        end

        initializer "decidim_helsinki_profile.verification_workflow", after: :load_config_initializers do
          next unless Decidim::HelsinkiProfile.configured?

          # We cannot use the name `:helsinki_profile` for the verification
          # workflow because otherwise the route namespac
          # (decidim_helsinki_profile) would conflict with the main engine
          # controlling the authentication flows. The main problem that this
          # would bring is that the root path for this engine would not be
          # found.
          Decidim::Verifications.register_workflow(:helsinki_idp) do |workflow|
            workflow.engine = Decidim::HelsinkiProfile::Verification::Engine

            Decidim::HelsinkiProfile::Verification::Manager.configure_workflow(workflow)
          end
        end

        def load_seed
          # Enable the `:helsinki_idp` authorization
          org = Decidim::Organization.first
          org.available_authorizations << :helsinki_idp
          org.save!
        end
      end
    end
  end
end
