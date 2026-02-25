# frozen_string_literal: true

require "huefy"
require "webmock/rspec"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure.
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on Module and main.
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in random order to surface order dependencies.
  config.order = :random
  Kernel.srand config.seed
end
