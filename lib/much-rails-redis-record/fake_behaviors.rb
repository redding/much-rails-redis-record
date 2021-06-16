# frozen_string_literal: true

module MuchRailsRedisRecord; end

module MuchRailsRedisRecord::FakeBehaviors
  include MuchRails::Mixin

  mixin_instance_methods do
    def initialize(
          identifier: Value.not_given,
          created_at: Value.not_given,
          updated_at: Value.not_given,
          **kargs)
      super(
        identifier: Value.given?(identifier) ? identifier : Factory.uuid,
        created_at: Value.given?(created_at) ? created_at : Factory.time.utc,
        updated_at: Value.given?(updated_at) ? updated_at : Factory.time.utc,
        **kargs,
      )
    end

    def save_bang_called?
      !!@save_bang_called
    end

    def destroy_bang_called?
      !!@destroy_bang_called
    end

    def save!
      validate!
      set_save_transaction_data

      @save_bang_called = true

      true
    end

    def destroy!
      @destroy_bang_called = true if identifier
    end
  end

  Value = MuchRailsRedisRecord::Value
end
