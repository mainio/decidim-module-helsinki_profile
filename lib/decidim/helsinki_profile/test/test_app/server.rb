# frozen_string_literal: true

require "puma"
require "puma/server"

module Decidim
  module HelsinkiProfile
    module Test
      module TestApp
        # A wrapper for puma to start the servers for the testing apps.
        class Server
          def initialize(app)
            @app = app
          end

          def serve(port, name:)
            conf = Puma::Configuration.new do |user_config|
              user_config.port(port, "127.0.0.1")
              user_config.app(app)
              user_config.log_requests
              user_config.tag(name)
            end
            @launcher = Launcher.new(conf, events: Puma::Events.stdio)
            @launcher.run
          end

          def graceful_stop
            return unless @launcher

            @launcher.graceful_stop
          end

          def stop
            return unless @launcher

            @launcher.stop
          end

          private

          attr_reader :app

          # Override the launcher class to disable the signals as we handle
          # them within the main process as we want to shut down all servers at
          # once.
          class Launcher < Puma::Launcher
            private

            # Disable signals
            def setup_signals; end
          end
        end
      end
    end
  end
end
