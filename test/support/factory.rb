# frozen_string_literal: true

require "assert/factory"

module Factory
  extend Assert::Factory

  def self.uuid
    SecureRandom.uuid
  end
end
