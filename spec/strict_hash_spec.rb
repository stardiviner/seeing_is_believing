require 'seeing_is_believing/strict_hash'

RSpec.describe SeeingIsBelieving::StrictHash do
  let(:klass) {
    klass = Class.new(described_class)
    class << klass
      public :attribute
      public :attributes
      public :predicate
      public :predicates
    end
    klass
  }

  def eq!(expected, actual, *message)
    expect(actual).to eq(expected), *message
  end

  def raises!(*exception_class_and_matcher, &block)
    expect(&block).to raise_error(*exception_class_and_matcher)
  end

  describe 'declaration' do
    describe 'attributes' do
      specify 'can be individually declared, requiring a default value or init block using .attribute' do
        eq! 1, klass.attribute(:a,   1 ).new.a
        eq! 2, klass.attribute(:b) { 2 }.new.b
        raises!(ArgumentError) { klass.attribute :c }
      end

      specify 'the block form is always called' do
        klass.attribute(:a,   "a" ).new.a << "-modified"
        eq! "a-modified", klass.new.a

        klass.attribute(:b) { "b" }.new.b << "-modified"
        eq! "b",          klass.new.b
      end

      specify 'can be group declared with a default value using .attributes(hash)' do
        klass.attributes a: 1, b: 2
        eq! 1, klass.new.a
        eq! 2, klass.new.b
      end
    end

    describe 'predicates are attributes which' do
      specify 'can be individually declared with .predicate' do
        eq! 1, klass.predicate(:a,   1 ).new.a
        eq! 2, klass.predicate(:b) { 2 }.new.b
        raises!(ArgumentError) { klass.predicate :c }
      end
      specify 'can be group declared with .predicates' do
        klass.predicates a: 1, b: 2
        eq! 1, klass.new.a
        eq! 2, klass.new.b
      end
    end

    describe 'conflicts' do
      it 'raises if you double-declare an attribute' do
        klass.attribute :a, 1
        raises!(ArgumentError) { klass.attribute :a, 2 }
        raises!(ArgumentError) { klass.predicate :a, 3 }
        raises!(ArgumentError) { klass.attributes a: 4 }
        raises!(ArgumentError) { klass.predicates a: 5 }
        eq! 1, klass.new.a

        klass.predicate :b, 1
        raises!(ArgumentError) { klass.attribute :b, 2 }
        raises!(ArgumentError) { klass.predicate :b, 3 }
        raises!(ArgumentError) { klass.attributes b: 4 }
        raises!(ArgumentError) { klass.predicates b: 5 }
        eq! 1, klass.new.b
      end
    end

    describe '.attribute / .attributes / .predicate / .predicates' do
      specify 'are private' do
        raises!(NoMethodError) { Class.new(described_class).attribute :a, 1 }
        eq! 1, Class.new(described_class) { attribute :a, 1 }.new.a
      end

      specify 'raise if a key is not a symbol (you shouldn\'t be dynamically creating this class with strings)' do
        raises!(ArgumentError) { klass.attribute 'a', 1 }
        raises!(ArgumentError) { klass.predicate 'b', 1 }
        raises!(ArgumentError) { klass.attributes 'c' => 1 }
        raises!(ArgumentError) { klass.predicates 'd' => 1 }
      end
    end
  end


  describe 'use' do
    describe 'initialization' do
      it 'sets all values to their defaults, calling the init blocks at that time' do
        calls = []
        klass.attribute(:a) { calls << :a; 1 }.attribute(:b, 2).attributes(c: 3)
             .predicate(:d) { calls << :d; 4 }.predicate(:e, 5).predicates(f: 6)
        eq! [], calls
        instance = klass.new
        eq! [:a, :d], calls
        eq! 1, instance.a
        eq! 2, instance.b
        eq! 3, instance.c
        eq! 4, instance.d
        eq! 5, instance.e
        eq! 6, instance.f
        eq! [:a, :d], calls
      end
      it 'accepts a hash of any declard attribute overrides' do
        instance = klass.attributes(a: 1, b: 2).new(a: 3)
        eq! 3, instance.a
        eq! 2, instance.b
      end
      it 'accepts string and symbol keys' do
        instance = klass.attributes(a: 1, b: 2).new(a: 3, 'b' => 4)
        eq! 3, instance.a
        eq! 4, instance.b
      end
      it 'raises if initialized with attributes it doesn\'t know' do
        klass.attribute :a, 1
        raises!(KeyError) { klass.new b: 2 }
      end
    end

    describe '#[] / #[]=' do
      specify 'get/set an attribute using string or symbol' do
        instance = klass.attribute(:a, 1).new
        eq! 1, instance[:a]
        eq! 1, instance['a']
        instance[:a] = 2
        eq! 2, instance[:a]
        eq! 2, instance['a']
        instance['a'] = 3
        eq! 3, instance[:a]
        eq! 3, instance['a']
      end
      specify 'raise if given a key that is not an attribute' do
        instance = klass.attribute(:a, 1).new
        instance[:a]
        raises!(KeyError) { instance[:b] }

        instance[:a] = 2
        raises!(KeyError) { instance[:b] = 2 }
      end
    end

    describe 'setter, getter, predicate' do
      specify '#<attr>  gets the attribute' do
        eq! 1, klass.attribute(:a, 1).new.a
      end
      specify '#<attr>= sets the attribute' do
        instance = klass.attribute(:a, 1).new
        eq! 1, instance.a
        instance.a = 2
        eq! 2, instance.a
      end
      specify '#<attr>? is an additional predicate getter' do
        klass.attribute(:a, 1).attributes(b: 2)
             .predicate(:c, 3).predicates(d: 4)
        instance = klass.new
        raises!(NoMethodError) { instance.a? }
        raises!(NoMethodError) { instance.b? }
        instance.c?
        instance.d?
      end
      specify '#<attr>? returns true or false based on what the value would do in a conditional' do
        instance = klass.predicates(nil: nil, false: false, true: true, object: Object.new).new
        eq! false, instance.nil?
        eq! false, instance.false?
        eq! true,  instance.true?
        eq! true,  instance.object?
      end
    end

    # include a fancy inspect with optional color?, optional width? tabular format?
    describe 'inspection' do
      class Example < described_class
        attributes a: 1, b: "c"
      end
      it 'inspects prettily' do
        eq! '#<StrictHash Example: {a: 1, b: "c"}>', Example.new.inspect
        klass.attributes(c: /d/)
        eq! '#<StrictHash subclass: {c: /d/}>', klass.new.inspect
      end
    end

    describe '#to_hash / #to_h' do
      it 'returns a dup\'d Ruby hash of the internal attributes' do
        klass.attributes(a: 1, b: 2)
        eq!({a: 1, b: 3}, klass.new(b: 3).to_hash)
        eq!({a: 3, b: 2}, klass.new(a: 3).to_h)

        instance = klass.new
        instance.to_h[:a] = :injected
        eq!({a: 1, b: 2}, instance.to_h)
      end
    end

    describe 'merge' do
      before { klass.attributes(a: 1, b: 2, c: 3) }

      it 'returns a new instance with the merged values overriding its own' do
        merged = klass.new(b: -2).merge c: -3
        eq! klass, merged.class
        eq!({a: 1, b: -2, c: -3}, merged.to_h)
      end

      it 'does not modify the LHS or RHS' do
        instance   = klass.new b: -2
        merge_hash = {c: -3}
        instance.merge merge_hash
        eq!({a: 1, b: -2, c: 3}, instance.to_h)
        eq!({c: -3}, merge_hash)
      end
    end

    describe 'enumerability' do
      it 'is enumerable, iterating over each attribute(as symbol)/value pair' do
        klass.attributes(a: 1, b: 2)
        eq! [[:a, 1], [:b, 2]], klass.new.to_a
        eq! "a1b2", klass.new.each.with_object("") { |(k, v), s| s << "#{k}#{v}" }
      end
    end

    describe 'keys/values' do
      specify 'keys returns an array of symbols of all its attributes' do
        eq! [:a, :b], klass.attributes(a: 1, b: 2).new(b: 3).keys
      end
      specify 'values returns an array of symbol values' do
        eq! [1, 3], klass.attributes(a: 1, b: 2).new(b: 3).values
      end
    end

    describe '#key? / #has_key? / #include? / #member?' do
      specify 'return true iff the key (symbolic or string) is an attribute' do
        instance = klass.attributes(a: 1, b: nil, c: false).new
        [:key?, :has_key?, :include?, :member?].each do |predicate|
          [:a, :b, :c, 'a', 'b', 'c'].each do |key|
            eq! true, instance.__send__(predicate, key), "#{instance.inspect}.#{predicate}(#{key.inspect}) returned false"
          end
          eq! false, instance.__send__(predicate, :d)
          eq! false, instance.__send__(predicate, 'd')
          eq! false, instance.__send__(predicate, /b/)
        end
      end
    end

    specify 'accepts nil as a value (common edge case)' do
      klass.attributes default_is_nil: nil, default_is_1: 1

      # default init block
      instance = klass.new
      eq! nil, instance.default_is_nil
      eq! nil, instance[:default_is_nil]

      # overridden on initialization
      instance = klass.new default_is_1: nil
      eq! nil, instance.default_is_1
      eq! nil, instance[:default_is_1]

      # set with setter
      instance = klass.new
      instance.default_is_1 = nil
      eq! nil, instance.default_is_1
      eq! nil, instance[:default_is_1]

      # set with []= and symbol
      instance = klass.new
      instance[:default_is_1] = nil
      eq! nil, instance.default_is_1
      eq! nil, instance[:default_is_1]

      # set with []= and string
      instance = klass.new
      instance['default_is_1'] = nil
      eq! nil, instance.default_is_1
      eq! nil, instance[:default_is_1]

      # set after its been set to nil
      instance = klass.new
      instance[:default_is_nil] = nil
      instance[:default_is_nil] = nil
      instance.default_is_nil   = nil
      instance.default_is_nil   = nil
    end
  end
end
