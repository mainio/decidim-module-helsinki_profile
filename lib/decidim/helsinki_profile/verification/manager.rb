# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Verification
      class Manager
        def self.configure_workflow(workflow)
          Decidim::HelsinkiProfile.workflow_configurator.call(workflow)
        end

        def self.metadata_collector_for(oidc_attributes)
          Decidim::HelsinkiProfile.metadata_collector_class.new(oidc_attributes)
        end
      end
    end
  end
end
