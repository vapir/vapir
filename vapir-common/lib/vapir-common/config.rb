module Vapir
  class Configuration
    class Error < StandardError; end
    class BadKeyError < Error; end
    class NoValueError < Error; end
    
    class Option
      attr_reader :key, :validator
      def initialize(key, hash={})
        @key = key
        @validator = hash[:validator]
      end
      def validate!(value)
        case @validator
        when nil
          value
        when Proc
          @validator.call value
        when :boolean
          case value
          when 'true', true
            true
          when 'false', false
            false
          else
            raise ArgumentError, "value should look like a boolean for key #{key}; instead got #{value.inspect}"
          end
        when :numeric
          case value
          when Numeric
            value
          when String
            begin
              Float(value)
            rescue ArgumentError
              raise ArgumentError, "value should look like a number for key #{key}; instead got #{value.inspect}"
            end
          else
            raise ArgumentError, "value should look like a number for key #{key}; instead got #{value.inspect}"
          end
        else
          raise ArgumentError, "invalid validator given: #{@validotor.inspect}\nvalidator should be nil for unspecified, a Proc, or a symbol indicating a known validator type"
        end
      end
    end
    
    attr_reader :parent
    def initialize(parent, &block)
      @parent=parent
      @config_hash = {}
      @recognized_options = {}
      yield(self) if block_given?
    end
    def method_missing(method, *args)
      method=method.to_s
      if method =~ /\A([a-z_][a-z0-9_]*)([=?!])?\z/i
        method = $1
        special = $2
      else # don't deal with any special character crap 
        return super
      end
      case special
      when nil
        raise ArgumentError, "wrong number of arguments retrieving #{method} (#{args.size} for 0)" unless args.size==0
        read(method)
      when '='
        raise ArgumentError, "wrong number of arguments setting #{method} (#{args.size} for 1)" unless args.size==1
        update(method, *args)
      #when '?' # no defined behavior for ? or ! at the moment
      #when '!'
      else
        return super
      end
    end
    def [](key)
      read(key)
    end
    def []=(key, value)
      update(key, value)
    end
    def recognized_keys
      ((@parent ? @parent.recognized_keys : [])+@recognized_options.keys).uniq
    end
    def recognized_key?(key)
      key = validate_key_format!(key)
      recognized_keys.include?(key)
    end
    def recognize_key!(key)
      key = validate_key_format!(key)
      unless recognized_key?(key)
        raise BadKeyError, "Unrecognized key: #{key}"
      end
      key
    end
    def locally_defined_key?(key)
      key = validate_key_format!(key)
      @config_hash.key?(key)
    end
    def defined_key?(key)
      locally_defined_key?(key) || (parent && parent.defined_key?(key))
    end
    def validate_key_format!(key)
      unless key.is_a?(String) || key.is_a?(Symbol)
        raise BadKeyError, "key should be a String or Symbol; got #{key.inspect} (#{key.class})"
      end
      key=key.to_s.downcase
      unless key =~ /\A([a-z_][a-z0-9_]*)\z/
        raise BadKeyError, "key should be all alphanumeric/underscores, not starting with a number"
      end
      key
    end
    protected
    def recognized_options
      (@parent ? @parent.recognized_options : {}).merge(@recognized_options)
    end
    public
    def create(key, options={})
      key=validate_key_format!(key)
      if recognized_key?(key)
        raise "already created key #{key}"
      end
      @recognized_options[key]= Option.new(key, options)
    end
    def read(key)
      key = recognize_key! key
      if @config_hash.key?(key)
        @config_hash[key]
      elsif @parent
        @parent.read(key)
      else
        raise NoValueError, "There is no value defined for key #{key}"
      end
    end
    def update(key, value)
      key = recognize_key! key
      value = recognized_options[key].validate! value
      @config_hash[key]=value
    end
    def create_update(key, value, options={})
      create(key, options)
      update(key, value)
    end
    def update_hash(hash)
      hash.each do |k,v|
        update(k,v)
      end
    end
    def delete(key)
      key = check_key key
      @config_hash.delete(key)
    end
  end
  module Configurable
    attr_accessor :configuration_parent
    def config
      @configuration ||= Configuration.new(configuration_parent)
    end
  end
  
  @base_configuration=Configuration.new(nil)
  
  @yaml_configuration = Configuration.new(@base_configuration)
  # TODO: bring in YAML config to override base defaults 
  
  @env_configuration = Configuration.new(@yaml_configuration)
  class << @env_configuration
    def update_env
      ENV.each do |env_key, value|
        if env_key =~ /\Avapir_(.*)\z/i
          key = $1
          if recognized_key?(key)
            update(key, value)
          end
        end
      end
    end
  end
  @env_configuration.update_env
  
  @configuration_parent = @env_configuration
  extend Configurable # makes Vapir.config which is the in-process user-configurable one, overriding base, yaml, and env 
end
