# frozen_string_literal: true

require "much-rails"
require "hella-redis"
require "much-rails-redis-record/version"

module MuchRailsRedisRecord
  include MuchRails::Config
  include MuchRails::Mixin

  add_config

  mixin_included do
    attr_accessor :identifier, :created_at, :updated_at
  end

  mixin_class_methods do
    def TTL_SECS
      raise NotImplementedError
    end

    def REDIS_KEY_NAMESPACE
      raise NotImplementedError
    end

    def redis
      MuchRailsRedisRecord.config.redis
    end

    def redis_key(identifier)
      "#{self.REDIS_KEY_NAMESPACE}:#{identifier}"
    end

    def find_by_identifier(identifier)
      find_by_redis_key(redis_key(identifier))
    end

    def find_by_redis_key(redis_key)
      args =
        MuchRails::JSON.decode(
          redis.connection do |c|
            unless c.exists?(redis_key)
              raise MuchRailsRedisRecord::NotFoundError
            end

            c.get(redis_key)
          end,
        )
      new(**args.symbolize_keys)
    end

    # Note: this should not be used in production code for performance / memory
    # consumption reasons. This should only be used for debugging in development
    # and staging environments.
    def find_all_redis_keys
      redis.connection do |c|
        c.keys("#{self.REDIS_KEY_NAMESPACE}:*")
      end
    end

    # Note: this should not be used in production code for performance / memory
    # consumption reasons. This should only be used for debugging in development
    # and staging environments.
    def find_all
      find_all_redis_keys.map do |redis_key|
        find_by_redis_key(redis_key)
      end
    end
  end

  mixin_instance_methods do
    def initialize(
          identifier: Value.not_given,
          created_at: Value.not_given,
          updated_at: Value.not_given,
          **)
      @identifier = Value.given?(identifier) ? identifier : nil
      @created_at =
        Value.given?(created_at) ? MuchRails::Time.for(created_at) : nil
      @updated_at =
        Value.given?(updated_at) ? MuchRails::Time.for(updated_at) : nil

      @valid = nil
    end

    def valid?
      errors.clear
      on_validate
      errors.none?
    end

    def redis_key
      self.class.redis_key(identifier)
    end

    def ttl
      redis.connection{ |c| c.ttl(redis_key) }
    end

    def errors
      @errors ||= HashWithIndifferentAccess.new{ |hash, key| hash[key] = [] }
    end

    def save!
      validate!
      set_save_transaction_data

      redis.connection do |c|
        c.multi do
          c.set(
            redis_key,
            MuchRails::JSON.encode(
              to_h.merge({
                "identifier" => identifier,
                "created_at" => created_at.iso8601,
                "updated_at" => updated_at.iso8601,
              }),
            ),
          )
          c.expire(redis_key, self.class.TTL_SECS) if self.class.TTL_SECS
        end
      end

      true
    end

    def destroy!
      redis.connection{ |c| c.del(redis_key) } if identifier

      true
    end

    def to_h
      raise NotImplementedError
    end

    def ==(other)
      return super unless other.is_a?(self.class)

      to_h == other.to_h
    end

    private

    def redis
      self.class.redis
    end

    def set_save_transaction_data
      @identifier ||= SecureRandom.uuid
      @created_at ||= Time.now.utc
      @updated_at = Time.now.utc
    end

    def validate!
      raise(MuchRails::InvalidError.new(**errors)) unless valid?
    end

    def on_validate
    end
  end

  NotFoundError = Class.new(RuntimeError)

  module Value
    include MuchRails::NotGiven
  end

  class Config
    attr_accessor :redis
  end
end
