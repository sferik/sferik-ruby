# frozen_string_literal: true

RSpec.describe Sferik::Resource do
  let(:talk) { Sferik::Talk.new("title" => "Writing Fast Ruby", "event" => "Baruco", "featured" => true, "slides" => nil) }
  let(:home) { Sferik::Home.new("pages" => {"talks" => "/talks"}, "modules" => [{"id" => "whoami"}]) }

  describe "#attributes" do
    it "has string keys" do
      expect(talk.attributes.keys).to eq(%w[title event featured slides])
    end

    it "is deep-frozen" do
      raw = home.attributes

      expect([raw, raw["pages"], raw["modules"], raw["modules"].first, raw["modules"].first.keys.first].all?(&:frozen?)).to be(true)
    end
  end

  it "is frozen" do
    expect(talk).to be_frozen
  end

  describe ".new" do
    [nil, [["title", "Writing Fast Ruby"]], "title"].each do |attributes|
      it "raises ArgumentError for attributes of #{attributes.inspect}, which aren't a Hash" do
        expect { Sferik::Talk.new(attributes) }.to raise_error(ArgumentError, "attributes must be Hash, not #{attributes.inspect}")
      end
    end

    it "raises ArgumentError for a key that isn't a String, which a reader's name as a Symbol isn't" do
      expect { Sferik::Resume::Work.new(start_date: "2023-01") }.to raise_error(ArgumentError, "key must be String, not :start_date")
    end

    it "takes a Hash of another class" do
      expect(Sferik::Talk.new(Class.new(Hash)["title" => "Writing Fast Ruby"]).title).to eq("Writing Fast Ruby")
    end

    it "raises InvalidResponse for a value that isn't what the API documents, without a reader being called" do
      expect { Sferik::Talk.new("date" => "soon") }.to raise_error(Sferik::InvalidResponse, 'Sferik::Talk#date: "soon" isn\'t an ISO 8601 date')
    end

    it "raises InvalidResponse for one in a resource inside it, however deep" do
      expect { Sferik::Contributions.new("lastPush" => {"at" => "soon"}) }.to raise_error(Sferik::InvalidResponse, 'Sferik::Push#at: "soon" isn\'t an ISO 8601 time')
    end

    it "prepares each value as the resource, which has its attributes by then" do
      prepared = Class.new(described_class) { [prepare(:itself) { self }, prepare(:keys) { attributes.keys }, define_method(:values) { [prepared(:itself), prepared(:keys)] }, public(:values)] }
      resource = prepared.new("a" => 1)

      expect(resource.values).to eq([resource, ["a"]])
    end

    it "freezes what it prepares" do
      expect([home, talk, described_class.new({})].map { |resource| resource.instance_variable_get(:@prepared) }).to all(be_frozen)
    end
  end

  describe ".preparations" do
    it "is the block that makes each value, by name" do
      expect(Sferik::Push.__send__(:preparations)).to match(repo: Proc, sha: Proc, at: Proc)
    end

    it "is frozen, with or without any" do
      expect([Class.new(described_class) { attribute(:a) }, Class.new(described_class)].map { |resource| resource.__send__(:preparations) }).to all(be_frozen)
    end

    it "is empty for a resource that prepares nothing" do
      expect(Class.new(described_class).__send__(:preparations)).to eq({})
    end

    it "is what a resource inherits, when it prepares nothing" do
      expect(Class.new(Class.new(Sferik::Push)).__send__(:preparations).keys).to eq(%i[repo sha at])
    end

    it "is what a resource inherits, then its own" do
      expect(Class.new(Sferik::Push) { attribute(:branch) }.__send__(:preparations).keys).to eq(%i[repo sha at branch])
    end

    it "leaves the resource one inherits from as it was" do
      Class.new(Sferik::Push) { attribute(:branch) }

      expect(Sferik::Push.__send__(:preparations).keys).to eq(%i[repo sha at])
    end

    it "is returned by what adds to it" do
      prepared = Class.new(described_class)

      expect(prepared.__send__(:prepare, :a) { 1 }).to be(prepared.__send__(:preparations)).and(match(a: Proc))
    end
  end

  describe "readers" do
    it "read attributes" do
      expect([talk.title, talk.slides]).to eq(["Writing Fast Ruby", nil])
    end

    it "answer predicates with true or false" do
      expect([talk.featured?, Sferik::Talk.new({}).featured?]).to eq([true, false])
    end

    it "wrap lists in resources, frozen" do
      expect(Sferik::Talks.new("talks" => [{"title" => "x"}]).talks).to eq([Sferik::Talk.new("title" => "x")]).and(be_frozen)
    end

    it "raise InvalidResponse for a list of something other than objects" do
      expect { Sferik::Talks.new("talks" => ["x"]) }.to raise_error(Sferik::InvalidResponse, "Expected a JSON object for a Sferik::Talk, got String")
    end

    it "raise InvalidResponse for something other than an object" do
      expect { Sferik::Home.new("pages" => 1) }.to raise_error(Sferik::InvalidResponse, "Expected a JSON object for a Sferik::Home::Pages, got Integer")
    end

    it "raise InvalidResponse for a list that isn't one" do
      expect { Sferik::Talks.new("talks" => {"title" => "x"}) }.to raise_error(Sferik::InvalidResponse, "Sferik::Talks#talks: expected a JSON array, got Hash")
    end

    it "raise InvalidResponse for a list where there should be one object" do
      expect { Sferik::Home.new("pages" => [{}]) }.to raise_error(Sferik::InvalidResponse, "Expected a JSON object for a Sferik::Home::Pages, got Array")
    end

    # False is a value, not nothing: where something else belongs, it's the wrong one, as a number or a string is
    it "raises InvalidResponse for false where a resource belongs" do
      expect { Sferik::Home.new("pages" => false) }.to raise_error(Sferik::InvalidResponse, "Expected a JSON object for a Sferik::Home::Pages, got FalseClass")
    end

    it "raises InvalidResponse for false where a list of resources belongs" do
      expect { Sferik::Talks.new("talks" => false) }.to raise_error(Sferik::InvalidResponse, "Sferik::Talks#talks: expected a JSON array, got FalseClass")
    end

    it "raises InvalidResponse for false where a list of anything belongs" do
      expect { Sferik::NameChange.new("notes" => false) }.to raise_error(Sferik::InvalidResponse, "Sferik::NameChange#notes: expected a JSON array, got FalseClass")
    end

    it "raises InvalidResponse for false where a dictionary belongs" do
      expect { Sferik::Talks.new("places" => false) }.to raise_error(Sferik::InvalidResponse, "Sferik::Talks#places: expected a JSON object, got FalseClass")
    end

    it "raises InvalidResponse for false where a date belongs" do
      expect { Sferik::Talk.new("date" => false) }.to raise_error(Sferik::InvalidResponse, "Sferik::Talk#date: false isn't an ISO 8601 date")
    end

    it "raises InvalidResponse for false where a time belongs" do
      expect { Sferik::Push.new("at" => false) }.to raise_error(Sferik::InvalidResponse, "Sferik::Push#at: false isn't an ISO 8601 time")
    end

    it "takes null for nothing, wherever a resource, a list, a dictionary, a date, or a time belongs" do
      nothing = [Sferik::Home.new("pages" => nil).pages, Sferik::Talks.new("talks" => nil, "places" => nil).then { |talks| [talks.talks, talks.places] },
        Sferik::NameChange.new("notes" => nil).notes, Sferik::Talk.new("date" => nil).date, Sferik::Push.new("at" => nil).at]

      expect(nothing).to eq([nil, [[], {}], [], nil, nil])
    end

    it "leaves false as it is where anything may be" do
      expect(Sferik::Talk.new("title" => false).title).to be(false)
    end

    it "return the same resources each time" do
      expect([home.pages, home.modules, home.modules.first]).to eq([home.pages, home.modules, home.modules.first]).and(all(be_frozen))
        .and(satisfy { |values| values.zip([home.pages, home.modules, home.modules.first]).all? { |value, again| value.equal?(again) } })
    end

    it "return the same date and time each time, frozen" do
      day = Sferik::Day.new("date" => "2026-10-01")
      push = Sferik::Push.new("at" => "2026-10-01T12:00:00Z")

      expect([day.date, push.at]).to all(be_frozen).and(satisfy { |date, time| date.equal?(day.date) && time.equal?(push.at) })
    end

    it "read a missing list as an empty one, frozen" do
      expect(Sferik::Talks.new({}).talks).to eq([]).and(be_frozen)
    end

    it "read a null list as an empty one" do
      expect(Sferik::Talks.new("talks" => nil).talks).to eq([])
    end

    it "wrap the values of a dictionary in resources, frozen" do
      places = Sferik::Talks.new("places" => {"Barcelona" => {"country" => "Spain"}}).places

      expect(places).to eq("Barcelona" => Sferik::Place.new("country" => "Spain")).and(be_frozen)
    end

    it "read a missing dictionary as an empty one, frozen" do
      expect(Sferik::Talks.new({}).places).to eq({}).and(be_frozen)
    end

    it "read a null dictionary as an empty one" do
      expect(Sferik::Talks.new("places" => nil).places).to eq({})
    end

    it "raise InvalidResponse for a dictionary that isn't one" do
      expect { Sferik::Talks.new("places" => [1]) }.to raise_error(Sferik::InvalidResponse, "Sferik::Talks#places: expected a JSON object, got Array")
    end

    it "raise InvalidResponse for a dictionary of something other than objects" do
      expect { Sferik::Talks.new("places" => {"Barcelona" => 1}) }.to raise_error(Sferik::InvalidResponse, "Expected a JSON object for a Sferik::Place, got Integer")
    end

    it "read a list of strings as it is" do
      expect(Sferik::NameChange.new("notes" => ["a"]).notes).to eq(["a"])
    end

    it "read a missing list of strings as an empty one" do
      expect(Sferik::NameChange.new({}).notes).to eq([])
    end

    it "parse dates" do
      expect(Sferik::Day.new("date" => "2026-10-01").date).to eq(Date.new(2026, 10, 1))
    end

    it "parse times" do
      expect(Sferik::Push.new("at" => "2026-10-01T12:00:00Z").at).to eq(Time.utc(2026, 10, 1, 12))
    end

    it "leave a missing time nil" do
      expect(Sferik::Push.new({}).at).to be_nil
    end

    it "raise InvalidResponse for a date that isn't one" do
      expect { Sferik::Day.new("date" => "soon") }.to raise_error(Sferik::InvalidResponse, 'Sferik::Day#date: "soon" isn\'t an ISO 8601 date')
    end

    it "raise InvalidResponse for a time that isn't a string" do
      expect { Sferik::Push.new("at" => 1) }.to raise_error(Sferik::InvalidResponse, /isn't an ISO 8601 time/)
    end
  end

  describe ".attribute_names" do
    it "is frozen, as are the keys" do
      expect([Sferik::Push.attribute_names, Sferik::Push.__send__(:keys), Class.new(described_class).attribute_names, Class.new(described_class).__send__(:keys)]).to all(be_frozen)
    end

    it "is empty for a resource without readers" do
      expect(Class.new(described_class).attribute_names).to eq([])
    end

    it "lists the readers, in order" do
      expect(Sferik::Push.attribute_names).to eq(%i[repo sha at])
    end

    it "lists a predicate without its question mark" do
      expect(Sferik::Talk.attribute_names.last).to eq(:featured)
    end

    it "lists the readers a resource inherits, then its own" do
      expect(Class.new(Sferik::Push) { attribute(:branch) }.attribute_names).to eq(%i[repo sha at branch])
    end

    it "leaves the resource one inherits from as it was" do
      Class.new(Sferik::Push) { attribute(:branch) }

      expect([Sferik::Push.attribute_names, Sferik::Push.__send__(:keys)]).to eq([%i[repo sha at], %w[repo sha at]])
    end

    it "has the keys a resource inherits, when it declares no readers" do
      expect(Class.new(Class.new(Sferik::Push)).__send__(:keys)).to eq(%w[repo sha at])
    end

    it "has the keys a resource inherits, then its own" do
      expect(Class.new(Sferik::Push) { attribute(:pushed_by) }.__send__(:keys)).to eq(%w[repo sha at pushedBy])
    end
  end

  describe ".readers" do
    it "is the reader each name is read with" do
      expect(Sferik::Talk.__send__(:readers)).to include(title: :title, featured: :featured?)
    end

    it "is frozen, with or without readers" do
      expect([Sferik::Talk.__send__(:readers), Class.new(described_class).__send__(:readers)]).to all(be_frozen)
    end

    it "is empty for a resource without readers" do
      expect(Class.new(described_class).__send__(:readers)).to eq({})
    end

    it "is the readers a resource inherits, when it declares none" do
      expect(Class.new(Class.new(Sferik::Push)).__send__(:readers)).to eq(repo: :repo, sha: :sha, at: :at)
    end

    it "is the readers a resource inherits, then its own" do
      expect(Class.new(Sferik::Push) { predicate(:forced) }.__send__(:readers)).to eq(repo: :repo, sha: :sha, at: :at, forced: :forced?)
    end
  end

  describe "#to_h" do
    it "is a hash of the readers" do
      expect(Sferik::Push.new("repo" => "a/b", "sha" => "abc", "at" => "2026-10-01T12:00:00Z").to_h).to eq(repo: "a/b", sha: "abc", at: Time.utc(2026, 10, 1, 12))
    end

    it "has a predicate under its name without the question mark" do
      expect(talk.to_h.to_a.last).to eq([:featured, true])
    end
  end

  describe "a resource that inherits from another" do
    let(:talk) { Class.new(Sferik::Talk).new("title" => "Writing Fast Ruby", "featured" => true) }

    it "has its readers in to_h" do
      expect(talk.to_h).to include(title: "Writing Fast Ruby", featured: true)
    end

    it "matches a pattern of them" do
      expect(talk.deconstruct_keys(%i[title featured])).to eq(title: "Writing Fast Ruby", featured: true)
    end

    it "shows what it declares for inspect" do
      shown = stub_const("Sferik::Shown", Class.new(Sferik::Talks) { inspect_with(:speaker_deck) })

      expect(shown.new({}).inspect).to eq("#<Sferik::Shown speaker_deck=nil>")
    end

    it "shows what the resource it inherits from declares for inspect, when it declares none" do
      shown = stub_const("Sferik::Shown", Class.new(Class.new(Sferik::Talks)))

      expect(shown.new("speakerDeck" => "https://speakerdeck.com/sferik").inspect).to eq('#<Sferik::Shown size=0 speaker_deck="https://speakerdeck.com/sferik">')
    end

    it "shows its first three readers when it declares none for inspect" do
      shown = stub_const("Sferik::Shown", Class.new(Sferik::Push) { attribute(:branch) })

      expect(shown.new("repo" => "a/b").inspect).to eq('#<Sferik::Shown repo="a/b" sha=nil at=nil>')
    end
  end

  describe "#as_json" do
    # ActiveSupport gives every Enumerable an as_json that makes a list of it
    around do |example|
      Enumerable.define_method(:as_json) { |*| to_a }
      example.run
    ensure
      Enumerable.remove_method(:as_json)
    end

    it "is the raw attributes" do
      expect(talk.as_json).to be(talk.attributes)
    end

    it "takes the options ActiveSupport passes on" do
      expect(talk.as_json({only: ["title"]})).to be(talk.attributes)
    end

    {Sferik::Talks => "talks", Sferik::Projects => "projects", Sferik::Who => "users"}.each do |collection, key|
      it "is the raw attributes of #{collection}, not a list" do
        resource = collection.new(key => [{}])

        expect(resource.as_json).to be(resource.attributes)
      end
    end
  end

  describe "#to_json" do
    it "is the JSON the resource came from" do
      body = fixture("talks.json")

      expect(JSON.parse(Sferik::Talks.new(JSON.parse(body)).to_json)).to eq(JSON.parse(body))
    end

    it "works for a resource inside something else, however it's generated" do
      expect(JSON.pretty_generate([home])).to eq(JSON.pretty_generate([home.attributes]))
    end
  end

  describe "#deconstruct_keys" do
    it "works with pattern matching" do
      title = case talk
      in {title: String => title, featured: true} then title
      end

      expect(title).to eq("Writing Fast Ruby")
    end

    it "binds a predicate, by its name without the question mark" do
      bound = case talk
      in {featured:} then featured
      end

      expect(bound).to be(true)
    end

    it "gives a predicate when asked for it" do
      expect(talk.deconstruct_keys(%i[featured featured?])).to eq(featured: true)
    end

    it "gives every reader when asked for all" do
      expect(talk.deconstruct_keys(nil)).to include(title: "Writing Fast Ruby", event: "Baruco")
    end

    it "gives only the readers asked for that exist" do
      expect(talk.deconstruct_keys(%i[title nope])).to eq(title: "Writing Fast Ruby")
    end
  end

  describe "equality" do
    let(:same) { Sferik::Talk.new("title" => "Writing Fast Ruby", "event" => "Baruco", "featured" => true, "slides" => nil) }

    it "is equal to a resource of the same class with the same attributes" do
      expect([talk == same, talk.eql?(same), talk.hash == same.hash]).to eq([true, true, true])
    end

    it "finds an equal resource as a Hash key" do
      expect({talk => 1}[same]).to eq(1)
    end

    it "isn't equal to a resource of another class" do
      expect(talk).not_to eq(Sferik::Podcast.new(talk.attributes))
    end

    it "isn't equal to a resource with other attributes" do
      expect(talk).not_to eq(Sferik::Talk.new("title" => "Other"))
    end

    it "has a different hash code from a resource with other attributes" do
      expect(talk.hash).not_to eq(Sferik::Talk.new("title" => "Other").hash)
    end

    it "has a different hash code from a resource of another class" do
      expect(talk.hash).not_to eq(Sferik::Podcast.new(talk.attributes).hash)
    end
  end

  describe "declarations" do
    # Declared here rather than reused from the library, so that the declarations run while the specs do
    let(:example) do
      stub_const("Sferik::Example", Class.new(described_class) do
        attribute :first_name
        attribute :nickname, "alias"
        attribute :last_push, type: Sferik::Push
        list :pushes, type: Sferik::Push
        list :tags, "labels"
        list :pull_requests
        predicate :live_now
        predicate :ok, "isOK"
        timestamp :born_on, Date
        timestamp :seen, Time, "lastSeenAt"
        timestamp :since, Sferik.const_get(:PartialDate)
      end)
    end

    it "lists the readers, in order" do
      expect(example.attribute_names).to eq(%i[first_name nickname last_push pushes tags pull_requests live_now ok born_on seen since])
    end

    it "freeze the readers and the keys" do
      expect([example.attribute_names, example.__send__(:keys), example.__send__(:readers)]).to all(be_frozen)
    end

    it "return the reader's name" do
      names = Class.new(described_class).class_eval { [attribute(:a), predicate(:b), timestamp(:c, Date), list(:d), dictionary(:e, type: Sferik::Place)] }

      expect(names).to eq(%i[a b c d e])
    end

    it "read a camelCased key for a dictionary by default" do
      mapped = Class.new(described_class) { dictionary :by_name, type: Sferik::Place }

      expect([mapped.new("byName" => {"a" => {}}, "by_name" => {}).by_name.keys, mapped.__send__(:keys)]).to eq([["a"], ["byName"]])
    end

    it "raise InvalidResponse for a dictionary that isn't one, naming its reader" do
      mapped = stub_const("Sferik::Mapped", Class.new(described_class) { dictionary :by_name, type: Sferik::Place })

      expect { mapped.new("byName" => 1) }.to raise_error(Sferik::InvalidResponse, "Sferik::Mapped#by_name: expected a JSON object, got Integer")
    end

    it "read a missing dictionary as an empty one" do
      expect(Class.new(described_class) { dictionary :by_name, type: Sferik::Place }.new({}).by_name).to eq({})
    end

    it "read the key given for a dictionary" do
      mapped = Class.new(described_class) { dictionary :by_name, "places", type: Sferik::Place }

      expect(mapped.new("places" => {"a" => {}}).by_name).to eq("a" => Sferik::Place.new({}))
    end

    it "read a camelCased key by default" do
      expect(example.new("firstName" => "Erik", "first_name" => "wrong").first_name).to eq("Erik")
    end

    it "camelCase every underscore" do
      expect(Class.new(described_class) { attribute :a_b_c }.new("aBC" => 1).a_b_c).to eq(1)
    end

    it "read the key given" do
      expect(example.new("alias" => "sferik").nickname).to eq("sferik")
    end

    it "read nil for a missing key" do
      expect(example.new({}).first_name).to be_nil
    end

    it "leave a value without a type as it is" do
      expect(example.new("firstName" => {"a" => 1}).first_name).to eq("a" => 1)
    end

    it "wrap a single value in its type" do
      push = {"repo" => "a/b", "sha" => "abc", "at" => "2026-10-01T12:00:00Z"}

      expect(example.new("lastPush" => push).last_push).to eq(Sferik::Push.new(push))
    end

    it "wrap each value of a list in its type" do
      expect(example.new("pushes" => [{"repo" => "a/b"}]).pushes).to eq([Sferik::Push.new("repo" => "a/b")])
    end

    it "read a camelCased key for a list by default" do
      expect(example.new("pullRequests" => [1], "pull_requests" => [2]).pull_requests).to eq([1])
    end

    it "raise InvalidResponse for a list that isn't one, naming its reader" do
      expect { example.new("pushes" => 1) }.to raise_error(Sferik::InvalidResponse, "Sferik::Example#pushes: expected a JSON array, got Integer")
    end

    it "read a missing list as an empty one" do
      expect(example.new({}).pushes).to eq([])
    end

    it "read the key given for a list" do
      expect(example.new("tags" => ["a"], "labels" => ["b"]).tags).to eq(["b"])
    end

    it "leave a missing typed value nil" do
      expect(example.new({}).last_push).to be_nil
    end

    it "answer a predicate true only for true" do
      values = [true, "true", 1, false, nil].map { |value| example.new("liveNow" => value).live_now? }

      expect(values).to eq([true, false, false, false, false])
    end

    it "answer a predicate from the key given" do
      expect(example.new("isOK" => true).ok?).to be(true)
    end

    it "answer a predicate false for a missing key" do
      expect(example.new({}).live_now?).to be(false)
    end

    it "parse a date" do
      expect(example.new("bornOn" => "1983-01-01").born_on).to eq(Date.new(1983, 1, 1))
    end

    it "parse a time from the key given" do
      expect(example.new("lastSeenAt" => "2026-10-01T12:00:00Z").seen).to eq(Time.utc(2026, 10, 1, 12))
    end

    it "list the keys their readers read" do
      expect(example.__send__(:keys)).to eq(%w[firstName alias lastPush pushes labels pullRequests liveNow isOK bornOn lastSeenAt since])
    end

    it "parse a partial date" do
      expect(example.new("since" => "2008").since).to eq(Date.new(2008, 1, 1))
    end

    it "raise InvalidResponse for a partial date that isn't one, calling it a date" do
      expect { example.new("since" => "soon") }.to raise_error(Sferik::InvalidResponse, 'Sferik::Example#since: "soon" isn\'t an ISO 8601 date')
    end

    it "show the readers declared for inspect" do
      shown = stub_const("Sferik::Shown", Class.new(described_class) { [attribute(:a), attribute(:b), inspect_with(:b)] })

      expect(shown.new("a" => 1, "b" => 2).inspect).to eq("#<Sferik::Shown b=2>")
    end

    it "show a predicate declared for inspect, by its name" do
      shown = stub_const("Sferik::Shown", Class.new(described_class) { [predicate(:ok), inspect_with(:ok)] })

      expect(shown.new("ok" => true).inspect).to eq("#<Sferik::Shown ok=true>")
    end

    it "show a method that isn't a reader, if it's declared for inspect" do
      shown = stub_const("Sferik::Shown", Class.new(described_class) { [define_method(:size) { 2 }, inspect_with(:size)] })

      expect(shown.new({}).inspect).to eq("#<Sferik::Shown size=2>")
    end

    it "show only public methods" do
      shown = Class.new(described_class) { [define_method(:size) { 2 }, private(:size), inspect_with(:size)] }

      expect { shown.new({}).inspect }.to raise_error(NoMethodError, /private method 'size'/)
    end

    it "record a reader without a key of its own" do
      recorded = Class.new(described_class) { record(:total) }

      expect([recorded.attribute_names, recorded.__send__(:keys), recorded.__send__(:readers)]).to eq([[:total], [], {total: :total}])
    end

    it "record a reader that isn't its name" do
      recorded = Class.new(described_class) { [record(:a), record(:total, reader: :total?)] }

      expect(recorded.__send__(:readers)).to eq(a: :a, total: :total?)
    end

    it "return the readers declared for inspect" do
      expect(Class.new(described_class).class_eval { inspect_with(:a, :b) }).to eq(%i[a b])
    end

    it "read nil for a missing timestamp" do
      expect(example.new({}).born_on).to be_nil
    end

    it "raise InvalidResponse for a date that isn't one" do
      expect { example.new("bornOn" => "soon") }.to raise_error(Sferik::InvalidResponse, 'Sferik::Example#born_on: "soon" isn\'t an ISO 8601 date')
    end

    it "raise InvalidResponse for a time that isn't a string" do
      expect { example.new("lastSeenAt" => 1) }.to raise_error(Sferik::InvalidResponse, "Sferik::Example#seen: 1 isn't an ISO 8601 time")
    end
  end

  describe "#inspect" do
    it "shows only the class of a resource that declares no readers" do
      expect(described_class.new("a" => 1).inspect).to eq("#<Sferik::Resource>")
    end

    it "shows the first readers" do
      expect(talk.inspect).to eq('#<Sferik::Talk title="Writing Fast Ruby" event="Baruco" date=nil>')
    end

    it "shows a date as its day alone" do
      expect(Sferik::Talk.new("title" => "Writing Fast Ruby", "event" => "Baruco", "date" => "2014-09").inspect)
        .to eq('#<Sferik::Talk title="Writing Fast Ruby" event="Baruco" date=#<Date: 2014-09-01>>')
    end

    it "shows a time, which is a date and more, as it shows itself" do
      session = Sferik::Session.new("tty" => "ttys001", "page" => "/", "login" => "2026-10-06T12:00:00Z")

      expect(session.inspect).to eq('#<Sferik::Session tty="ttys001" page="/" login=2026-10-06 12:00:00 UTC>')
    end

    it "shows a kind of date that isn't Date as it shows itself" do
      shown = stub_const("Sferik::Shown", Class.new(described_class) { [timestamp(:at, DateTime), inspect_with(:at)] })

      expect(shown.new("at" => "2014-09-01T00:00:00Z").inspect).to eq("#<Sferik::Shown at=#{DateTime.new(2014, 9, 1).inspect}>")
    end

    it "shows who the home page is about, not each of its modules" do
      expect(home.inspect).to eq("#<Sferik::Home profile=nil>")
    end

    it "shows the totals of contributions, not each day" do
      contributions = Sferik::Contributions.new("total" => 5242, "longestStreak" => 30, "since" => 2008, "contributions" => [{"count" => 1}])

      expect(contributions.inspect).to eq("#<Sferik::Contributions total=5242 longest_streak=30 since=2008>")
    end

    it "shows the command and the downloads of the bio, not each paragraph" do
      whoami = Sferik::Whoami.new("command" => "whoami", "multiDownloads" => 1, "blocks" => [{"type" => "p"}])

      expect(whoami.inspect).to eq('#<Sferik::Whoami command="whoami" multi_downloads=1>')
    end

    it "shows where a figure is from, not all it says" do
      figure = Sferik::Figure.new("type" => "figure", "href" => "https://xkcd.com/2347/", "src" => "/img/dependency.webp", "alt" => "A tower")

      expect(figure.inspect).to eq('#<Sferik::Figure href="https://xkcd.com/2347/" src="/img/dependency.webp">')
    end
  end
end
