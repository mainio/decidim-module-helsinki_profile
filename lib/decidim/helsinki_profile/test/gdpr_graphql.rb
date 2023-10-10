# frozen_string_literal: true

module Decidim
  module HelsinkiProfile
    module Test
      # This module implements some of the API types/nodes provided by the
      # Helsinki profile GraphQL API to create a local test API to test the
      # integration against during the tests. This simulates the GDPR API based
      # on its documentation at the time of writing the two-way integration.
      #
      # Note that this is not a complete implementation of the API as in
      # Helsinki profile. This only focuses on the parts that are needed for the
      # Decidim integration.
      module GdprGraphql
        autoload :MutationType, "decidim/helsinki_profile/test/gdpr_graphql/mutation_type"
        autoload :QueryType, "decidim/helsinki_profile/test/gdpr_graphql/query_type"
        autoload :Schema, "decidim/helsinki_profile/test/gdpr_graphql/schema"
        autoload :Server, "decidim/helsinki_profile/test/gdpr_graphql/server"
        autoload :AuthorizedField, "decidim/helsinki_profile/test/gdpr_graphql/authorized_field"

        # GraphQL
        autoload :AddressNode, "decidim/helsinki_profile/test/gdpr_graphql/types/address_node"
        autoload :AddressType, "decidim/helsinki_profile/test/gdpr_graphql/types/address_type"
        autoload :EmailNode, "decidim/helsinki_profile/test/gdpr_graphql/types/email_node"
        autoload :EmailType, "decidim/helsinki_profile/test/gdpr_graphql/types/email_type"
        autoload :ProfileNode, "decidim/helsinki_profile/test/gdpr_graphql/types/profile_node"
        autoload :VerifiedPersonalInformationAddressNode, "decidim/helsinki_profile/test/gdpr_graphql/types/verified_personal_information_address_node"
        autoload :VerifiedPersonalInformationForeignAddressNode, "decidim/helsinki_profile/test/gdpr_graphql/types/verified_personal_information_foreign_address_node"
        autoload :VerifiedPersonalInformationNode, "decidim/helsinki_profile/test/gdpr_graphql/types/verified_personal_information_node"
      end
    end
  end
end
