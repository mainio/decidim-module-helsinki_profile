# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    class SessionInfo < ApplicationRecord
      belongs_to :user, -> { respond_to?(:entire_collection) ? entire_collection : self }, foreign_key: :decidim_user_id, class_name: "Decidim::User"
    end
  end
end
