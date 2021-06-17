# MuchRailsRedisRecord

Store records in Redis with MuchRails.

Note: I find redis to be a good choice for one-off "token" type records or any temporary record you want removed after a certain amount of time. MuchRailsRedisRecord is ideal for these types of records.

For typical records in Rails, ActiveRecord should be preferred.

## Setup

### Mixin on your record object you want persisted in Redis, e.g.:

```ruby
class Thing
  include MuchRailsRedisRecord

  def self.TTL_SECS
    @ttl_secs ||= 5 * 60 # 5 minutes
  end

  def self.REDIS_KEY_NAMESPACE
    "things"
  end

  attr_accessor :name

  def initialize(name:, **kargs)
    super(**kargs)

    @name = name
  end

  def to_h
    {
      "name" => name,
    }
  end

  private

  def on_validate
    validate_presence
  end

  def validate_presence
    errors[:name] << "can't be blank" if name.blank?
  end
end
```

### Configure the redis connection

In e.g. `config/initializers/much_rails.rb`:

```ruby
MuchRailsRedisRecord.config.redis =
  HellaRedis.new({
    url: ENV.fetch("REDIS_URL"){ "redis://localhost:6379/0" },
    driver: "ruby",
    redis_ns: "my-app",
    size: ENV.fetch("APP_MAX_THREADS"){ 5 },
    timeout: 1,
  })
```

## Usage

```
$ rails c
Loading development environment (Rails 6.1.3.1)
[1] pry(main)> chair = Thing.new(name: "Chair")
=> #<Thing:0x00007fd404182358 @created_at=nil, @identifier=nil, @name="Chair", @updated_at=nil, @valid=nil>
[2] pry(main)> chair.save!
=> true
[3] pry(main)> chair
=> #<Thing:0x00007fd404182358 @created_at=2021-06-17 13:16:52.059503 UTC, @errors={}, @identifier="6600bdd3-4dc8-447b-910a-3cf079eaae98", @name="Chair", @updated_at=2021-06-17 13:16:52.059506 UTC, @valid=nil>
[4] pry(main)> chair.name = "Comfy chair"
=> "Comfy chair"
[5] pry(main)> chair.save!
=> true
[6] pry(main)> chair
=> #<Thing:0x00007fd404182358 @created_at=2021-06-17 13:16:52.059503 UTC, @errors={}, @identifier="6600bdd3-4dc8-447b-910a-3cf079eaae98", @name="Comfy chair", @updated_at=2021-06-17 13:17:12.409879 UTC, @valid=nil>
[7] pry(main)> chair.valid?
=> true
[8] pry(main)> chair.name = nil
=> nil
[9] pry(main)> chair.valid?
=> false
[10] pry(main)> chair.save!
MuchRails::InvalidError: {"name"=>["can't be blank"]}
from /Users/kelly/projects/redding/gems/much-rails-redis-record/lib/much-rails-redis-record.rb:156:in `validate!'
[11] pry(main)> chair.name = "Comfy chair"
=> "Comfy chair"
[12] pry(main)> chair.valid?
=> true
[13] pry(main)> chair.ttl
=> 242
[14] pry(main)> chair.ttl
=> 239
[15] pry(main)> chair.ttl
=> 235
[16] pry(main)> chair.redis_key
=> "things:6600bdd3-4dc8-447b-910a-3cf079eaae98"
[17] pry(main)> Thing.find_by_identifier("6600bdd3-4dc8-447b-910a-3cf079eaae98")
=> #<Thing:0x00007fd4043d97c8 @created_at=2021-06-17 13:16:52 UTC, @identifier="6600bdd3-4dc8-447b-910a-3cf079eaae98", @name="Comfy chair", @updated_at=2021-06-17 13:17:12 UTC, @valid=nil>
[18] pry(main)> chair == Thing.find_by_identifier("6600bdd3-4dc8-447b-910a-3cf079eaae98")
=> true
[19] pry(main)> Thing.find_all
=> [#<Thing:0x00007fd40440af30 @created_at=2021-06-17 13:16:52 UTC, @identifier="6600bdd3-4dc8-447b-910a-3cf079eaae98", @name="Comfy chair", @updated_at=2021-06-17 13:17:12 UTC, @valid=nil>]
[20] pry(main)> chair.destroy!
=> true
[21] pry(main)> Thing.find_all
=> []
[22] pry(main)>
```

## Testing

### Fake redis records

Use `MuchRailsRedisRecord::FakeBehaviors` to create test doubles for your redis records. The test doubles have the same API but won't call out to redis to persist.

E.g.

```ruby
require "much-rails-redis-record/fake_behaviors"

class Factory::FakeThing < Thing
  include MuchRailsRedisRecord::FakeBehaviors

  def initialize(name: nil, **kargs)
    super(name || Factory.string, **kargs)
  end
end
```

```
[3] pry(main)> fake_thing = Factory::FakeThing.new
=> #<Factory::FakeThing:0x00007f98b0865740 @created_at=2000-12-21 05:11:53 UTC, @identifier="6c8f6609-b459-4a8f-b5e2-df1bb02efbaa", @name="ygzzysbhip", @updated_at=2000-04-01 02:17:30 UTC, @valid=nil>
[4] pry(main)> Thing.find_all
=> []
[5] pry(main)>
```

## Installation

Add this line to your application's Gemfile:

    gem "much-rails-redis-record"

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install much-rails-redis-record

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am "Added some feature"`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
