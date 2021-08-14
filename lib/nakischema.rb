module Nakischema
  Error = Class.new RuntimeError
  def self.validate object, schema, path = []
    raise_with_path = lambda do |msg|
      raise Error.new "#{msg}#{" (at #{path})" unless path.empty?}"
    end
    case schema
    when Hash
      raise_with_path.call "expected Hash != #{object.class}" unless object.is_a? Hash unless (schema.keys & %i{ keys_sorted keys values }).empty?
      raise_with_path.call "expected Array != #{object.class}" unless object.is_a? Array unless (schema.keys & %i{ size }).empty?
      schema.each do |k, v|
        case k
        # when :keys_sorted ; raise_with_path.call "expected explicit keys #{v} != #{object.keys.sort}" unless v == object.keys.sort
        when :size ; raise_with_path.call "expected explicit size #{v} != #{object.size}" unless v.include? object.size
        # when Fixnum
        #   raise_with_path.call "expected Array != #{object.class}" unless object.is_a? Array
        #   validate object[k], v, [*path, "##{k}"]
        when :keys ; validate object.keys, v, [*path, :keys]
        when :hash_opt ; v.each{ |k, v| validate object[k], v, [*path, k] if object.key? k }
        when :hash
          raise_with_path.call "expected implicit keys #{v} != #{object.keys.sort}" unless v.keys.sort == object.keys.sort
          v.each{ |k, v| validate object.fetch(k), v, [*path, k] }
        when :each_key ; object.keys.each_with_index{ |k, i| validate k, v, [*path, :"key##{i}"] }
        when :each_value ; object.values.each_with_index{ |v_, i| validate v_, v, [*path, :"value##{i}"] }
        when :each
          raise_with_path.call "expected iterable != #{object.class}" unless object.respond_to? :each_with_index
          object.each_with_index{ |e, i| validate e, v, [*path, :"##{i}"] }
        # when :case
        #   raise_with_path.call "expected at least one of #{v.size} cases to match the #{object.inspect}" if v.map.with_index do |(k, v), i|
        #     next if begin
        #       validate object, k
        #       nil
        #     rescue Error => e
        #       e
        #     end
        #     validate object, v, [*path, :"case##{i}"]
        #     true
        #   end.none?
        when :assertions ; v.each_with_index{ |assertion, i| raise_with_path.call "custom assertion failed" unless assertion.call object, [*path, :"assertion##{i}"] }
        else ; raise_with_path.call "unsupported rule #{k.inspect}"
        end
      end
    when NilClass, TrueClass, FalseClass, String ; raise_with_path.call "expected #{schema.inspect} != #{object.inspect}" unless schema == object
    when Regexp                                  ; raise_with_path.call "expected #{schema        } != #{object.inspect}" unless schema === object
    when Range                                   ; raise_with_path.call "expected #{schema        } != #{object        }" unless schema.include? object
    when Array
      if schema.map(&:class) == [Array]
        raise_with_path.call "expected Array != #{object.class}" unless object.is_a? Array
        raise_with_path.call "expected implicit size #{schema[0].size} != #{object.size}" unless schema[0].size == object.size
        object.zip(schema[0]).each_with_index do |(o, v), i|
          validate o, v, [*path, :"##{i}"]
        end
      else
        results = schema.lazy.with_index.map do |v, i|
          # raise_with_path.call "unsupported nested Array" if v.is_a? Array
          begin
            validate object, v, [*path, "variant##{i}"]
            nil
          rescue Error => e
            e
          end
        end
        raise_with_path.call \
          "expected at least one of #{schema.size} rules to match the #{object.inspect}, errors:\n" +
          results.force.compact.map{ |_| _.to_s.gsub(/^/, "  ") }.join("\n") if results.all?
      end
    else ; raise_with_path.call "unsupported rule class #{schema.class}"
    end
  end
end