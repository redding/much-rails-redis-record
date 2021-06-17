# frozen_string_literal: true

require "assert"
require "much-rails-redis-record"

module MuchRailsRedisRecord
  class UnitTests < Assert::Context
    desc "MuchRailsRedisRecord"
    subject{ unit_module }

    let(:unit_module){ MuchRailsRedisRecord }
  end

  class ReceiverTests < UnitTests
    desc "receiver"
    subject{ receiver_class }

    setup do
      redis.reset!

      secure_random_uuid
      Assert.stub(SecureRandom, :uuid){ secure_random_uuid }
    end

    teardown do
      redis.reset!
    end

    let(:receiver_class) do
      Class
        .new{
          def self.TTL_SECS
            1
          end

          def self.REDIS_KEY_NAMESPACE
            "test:redis-records"
          end

          attr_reader :field1

          def initialize(
                field1:,
                **kargs)
            super(**kargs)

            @field1 = field1.to_s.strip
          end

          def to_h
            {
              "field1" => field1,
            }
          end

          private

          def on_validate
            validate_presence
          end

          def validate_presence
            errors[:field1] << "can’t be blank" if field1.blank?
          end
        }
        .tap do |c|
          c.include(unit_module)
        end
    end

    let(:redis){ unit_module.config.redis }
    let(:secure_random_uuid){ Factory.uuid }

    let(:field1_value){ Factory.string }
    let(:identifier){ secure_random_uuid }
    let(:created_at){ Time.now.utc }
    let(:updated_at){ Time.now.utc }

    let(:record_data) do
      {
        "field1" => field1_value,
        "identifier" => identifier,
        "created_at" => created_at.iso8601,
        "updated_at" => updated_at.iso8601,
      }
    end

    should have_imeths :TTL_SECS, :REDIS_KEY_NAMESPACE
    should have_imeths :redis_key, :find_by_identifier, :find_by_redis_key
    should have_imeths :find_all_redis_keys, :find_all

    should "know its attributes" do
      assert_that(subject.TTL_SECS).equals(1)
      assert_that(subject.REDIS_KEY_NAMESPACE).equals("test:redis-records")
      assert_that(subject.redis_key(secure_random_uuid))
        .equals("#{subject.REDIS_KEY_NAMESPACE}:#{identifier}")
    end
  end

  class FindByIdentifierSetupTests < ReceiverTests
    desc ".find_by_identifier"

    setup do
      Assert
        .stub(redis.connection_spy, :get)
        .with(subject.redis_key(identifier)){ encoded_record_data }
    end

    let(:encoded_record_data){ MuchRails::JSON.encode(record_data) }
  end

  class FindByExistingIdentifierTests < FindByIdentifierSetupTests
    desc "with an existing identifier"

    setup do
      Assert
        .stub(redis.connection_spy, :exists?)
        .with(subject.redis_key(identifier)){ true }
    end

    should "lookup the existing record data and build an instance with it" do
      record = subject.find_by_identifier(identifier)
      assert_that(record).equals(subject.new(**record_data.symbolize_keys))
    end
  end

  class FindByNonExistingIdentifierTests < FindByIdentifierSetupTests
    desc "with an non-existing identifier"

    setup do
      Assert
        .stub(redis.connection_spy, :exists?)
        .with(subject.redis_key(identifier)){ false }
    end

    should "raise an exception" do
      assert_that{ subject.find_by_identifier(identifier) }
        .raises(subject::NotFoundError)
    end
  end

  class FindByRedisKeySetupTests < ReceiverTests
    desc ".find_by_redis_key"

    setup do
      Assert
        .stub(redis.connection_spy, :get)
        .with(subject.redis_key(identifier)){ encoded_record_data }
    end

    let(:encoded_record_data){ MuchRails::JSON.encode(record_data) }
  end

  class FindByExistingRedisKeyTests < FindByRedisKeySetupTests
    desc "with an existing redis key"

    setup do
      Assert
        .stub(redis.connection_spy, :exists?)
        .with(subject.redis_key(identifier)){ true }
    end

    should "lookup the existing record data and build an instance with it" do
      record = subject.find_by_redis_key(subject.redis_key(identifier))
      assert_that(record).equals(subject.new(**record_data.symbolize_keys))
    end
  end

  class FindByNonExistingRedisKeyTests < FindByRedisKeySetupTests
    desc "with an non-existing redis key"

    setup do
      Assert
        .stub(redis.connection_spy, :exists?)
        .with(subject.redis_key(identifier)){ false }
    end

    should "raise an exception" do
      assert_that{ subject.find_by_redis_key(subject.redis_key(identifier)) }
        .raises(subject::NotFoundError)
    end
  end

  class FindAllRedisKeysTests < ReceiverTests
    desc ".find_all_redis_keys"

    setup do
      Assert
        .stub(redis.connection_spy, :keys)
        .with("#{receiver_class.REDIS_KEY_NAMESPACE}:*"){ all_redis_keys }
    end

    let(:all_redis_keys) do
      Array.new(Factory.integer(3)) do
        "#{receiver_class.REDIS_KEY_NAMESPACE}:#{Factory.uuid}"
      end
    end

    should "lookup all redis keys matching the key namespace" do
      assert_that(subject.find_all_redis_keys).equals(all_redis_keys)
    end
  end

  class FindAllTests < ReceiverTests
    desc ".find_all_tests"

    setup do
      Assert.stub(receiver_class, :find_all_redis_keys) do
        redis_record_redis_keys
      end
      Assert
        .stub(receiver_class, :find_by_redis_key)
        .with(redis_record_redis_keys.first) do
          redis_records.first
        end
    end

    let(:redis_records) do
      [receiver_class.new(**record_data.symbolize_keys)]
    end
    let(:redis_record_redis_keys){ redis_records.map(&:redis_key) }

    should "lookup all redis keys matching the key namespace" do
      assert_that(subject.find_all).equals(redis_records)
    end
  end

  class InitTests < ReceiverTests
    desc "when init"
    subject{ receiver_class.new(field1: field1_value) }

    should have_imeths :valid?, :errors, :save!, :destroy!, :to_h

    should "know its attributes" do
      assert_that(subject.valid?).equals(true)
      assert_that(subject.errors).equals({})
      assert_that(subject.to_h)
        .equals({
          "field1" => field1_value,
        })
    end
  end

  class SaveSetupTests < InitTests
    desc ".save!"

    setup do
      create_time_now
      Assert.stub(Time, :now){ create_time_now }
    end

    let(:create_time_now){ Time.now }
  end

  class SaveNewRecordTests < SaveSetupTests
    desc "on a new record"

    should "set save data and save the record" do
      assert_that(subject.identifier).is_nil
      assert_that(subject.created_at).is_nil
      assert_that(subject.updated_at).is_nil

      result = subject.save!
      assert_that(result).is_true

      assert_that(subject.identifier).equals(identifier)
      assert_that(subject.created_at).equals(create_time_now)
      assert_that(subject.updated_at).equals(create_time_now)

      assert_that(redis.calls.size).equals(3)
      multi_call, set_call, expire_call = redis.calls

      assert_that(multi_call.command).equals(:multi)

      assert_that(set_call.command).equals(:set)
      assert_that(set_call.args)
        .equals([
          subject.class.redis_key(identifier),
          MuchRails::JSON.encode(
            subject.to_h.merge({
              "identifier" => subject.identifier,
              "created_at" => subject.created_at.iso8601,
              "updated_at" => subject.updated_at.iso8601,
            }),
          ),
        ])

      assert_that(expire_call.command).equals(:expire)
      assert_that(expire_call.args)
        .equals([subject.class.redis_key(identifier), subject.class.TTL_SECS])
    end
  end

  class SaveExistingRecordTests < SaveSetupTests
    desc "on an existing record"

    setup do
      subject.save!

      Assert.unstub(Time, :now)
      update_time_now
      Assert.stub(Time, :now){ update_time_now }

      redis.reset!
    end

    let(:update_time_now){ Time.now }

    should "set save data and save the record" do
      assert_that(subject.identifier).equals(identifier)
      assert_that(subject.created_at).equals(create_time_now)
      assert_that(subject.updated_at).equals(create_time_now)

      result = subject.save!
      assert_that(result).is_true

      assert_that(subject.identifier).equals(identifier)
      assert_that(subject.created_at).equals(create_time_now)
      assert_that(subject.updated_at).equals(update_time_now)
    end
  end

  class SaveWithNoTTLTests < SaveSetupTests
    desc "with no TTL_SECS"

    setup do
      Assert.stub(receiver_class, :TTL_SECS){ nil }
    end

    should "set save data and save the record" do
      subject.save!

      assert_that(redis.calls.size).equals(2)
      multi_call, set_call = redis.calls

      assert_that(multi_call.command).equals(:multi)
      assert_that(set_call.command).equals(:set)
    end
  end

  class SaveWithValidationErrorsTests < SaveSetupTests
    desc "with validation errors"

    setup do
      Assert.stub(subject, :field1){ [nil, ""].sample }
    end

    should "not set save data and not save the record" do
      assert_that(subject.valid?).equals(false)
      exception =
        assert_that{ subject.save! }.raises(MuchRails::InvalidError)

      assert_that(exception.errors).equals(subject.errors)
      assert_that(redis.calls.size).equals(0)
    end
  end

  class DestroySetupTests < InitTests
    desc ".destroy!"
  end

  class DestroyNewRecordTests < DestroySetupTests
    desc "on a new record"

    should "do nothing in Redis" do
      assert_that(subject.identifier).is_nil

      result = subject.destroy!
      assert_that(result).is_true

      assert_that(redis.calls.size).equals(0)
    end
  end

  class DestroyExistingRecordTests < DestroySetupTests
    desc "on an existing record"

    setup do
      subject.save!
      redis.reset!
    end

    should "delete the record in Redis" do
      assert_that(subject.identifier).is_not_nil

      result = subject.destroy!
      assert_that(result).is_true

      assert_that(redis.calls.size).equals(1)
      delete_call = redis.calls.last

      assert_that(delete_call.command).equals(:del)
      assert_that(delete_call.args)
        .equals([subject.class.redis_key(identifier)])
    end
  end
end
