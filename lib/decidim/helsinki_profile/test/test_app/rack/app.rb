# frozen_string_literal: true

require "rack"

module Decidim
  module HelsinkiProfile
    module Test
      module TestApp
        module Rack
          class App
            def call(env)
              request = Request.new(env)

              serve(request)
            end

            private

            def serve(request)
              raise NotImplementedError, "Implement the `#serve` method for the app."
            end

            def logger
              @logger ||= Logger.new($stdout).tap do |log|
                log.level = Logger::DEBUG
              end
            end

            def not_found
              [404, { "Content-Type" => "text/plain" }, ["Not found."]]
            end

            def unauthorized
              [401, { "Content-Type" => "text/plain" }, ["Unauthorized"]]
            end
          end

          class Request < ::Rack::Request
            attr_reader :headers

            def initialize(env)
              super

              @headers =
                env
                .select { |k, _| k.start_with? "HTTP_" }
                .transform_keys { |k| k.sub(/^HTTP_/, "").split("_").collect(&:capitalize).join("-") }

              @headers["Content-Type"] ||= env["CONTENT_TYPE"]
            end
          end
        end
      end
    end
  end
end
