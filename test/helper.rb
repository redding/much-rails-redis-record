# frozen_string_literal: true

ENV["HELLA_REDIS_TEST_MODE"] = "yes"

# Add the root dir to the load path.
$LOAD_PATH.unshift(File.expand_path("../..", __FILE__))

# Require pry for debugging (`binding.pry`).
require "pry"

require "test/support/factory"
require "much-rails-redis-record"

MuchRailsRedisRecord.configure do |config|
  config.redis =
    HellaRedis.new({
      url: ENV.fetch("REDIS_URL"){ "redis://localhost:6379/0" },
      driver: "ruby",
      redis_ns: "much-rails-redis-record:tests",
      size: ENV.fetch("APP_MAX_THREADS"){ 5 },
      timeout: 1,
    })
end
