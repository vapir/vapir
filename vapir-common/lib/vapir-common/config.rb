module Vapir
  # represents a entry in a heirarchy of configuration options 
  class Configuration
    class Error < StandardError; end
    class BadKeyError < Error; end
    class NoValueError < Error; end
    
    # represents a valid option on a Configuration. consists of a key and criteria
    # for which a value is valid for that key. 
    class Option
      attr_reader :key, :validator
      # creates a new option. the options hash (last argument) may specify a 
      # :validator key which will be used to validate any values attempted to be
      # assigned to the key this option represents. 
      def initialize(key, hash={})
        @key = key
        @validator = hash[:validator]
      end
      # takes a value and checks that it is valid, if a validator is specified for 
      # this option. the validator may map the value to something different, so the
      # result of this function call should replace the value being used. 
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
    
    # the parent Configuration in the heirarchy. may be nil if there is no parent. 
    attr_reader :parent
    # creates a new Configuration with the given parent. if a block is given, this
    # Configuration object will be yielded to it. 
    def initialize(parent, &block)
      @parent=parent
      @config_hash = {}
      @recognized_options = {}
      yield(self) if block_given?
    end
    # if the method invoked looks like assignment (ends with an =), calls to #update with 
    # the given method as the key and its argument as the value. otherwise calls #read with 
    # the method as the key. 
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
    # alias for #read
    def [](key)
      read(key)
    end
    # alias for #update 
    def []=(key, value)
      update(key, value)
    end
    # returns an array of 
    def recognized_keys
      ((@parent ? @parent.recognized_keys : [])+@recognized_options.keys).uniq
    end
    # returns true if the given key is recognized; false otherwise. may raise BadKeyError
    # if the given key isn't even a valid format for a key. 
    def recognized_key?(key)
      key = validate_key_format!(key)
      recognized_keys.include?(key)
    end
    # assert that the given key must be recognized; if it is not recognized, an error 
    # should be raised. 
    def recognize_key!(key)
      key = validate_key_format!(key)
      unless recognized_key?(key)
        raise BadKeyError, "Unrecognized key: #{key}"
      end
      key
    end
    # returns true if the given key is defined on this Configuration; returns false if not - 
    # note that this returns false if the given key is defined on an ancestor Configuration. 
    def locally_defined_key?(key)
      key = validate_key_format!(key)
      @config_hash.key?(key)
    end
    # returns true if the given key is defined on this Configuration or any of its ancestors. 
    def defined_key?(key)
      locally_defined_key?(key) || (parent && parent.defined_key?(key))
    end
    # raises an error if the given key is not in an acceptable format. the key should be a string
    # or symbol consisting of alphanumerics and underscorse, beginning with an alpha or underscore. 
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
    # returns a hash of recognized options with the keys being recognized keys and values 
    # being Option instances. 
    def recognized_options
      (@parent ? @parent.recognized_options : {}).merge(@recognized_options)
    end
    public
    # creates a new key. options are passed to Option.new; see its documentation. 
    def create(key, options={})
      key=validate_key_format!(key)
      if recognized_key?(key)
        raise "already created key #{key}"
      end
      @recognized_options[key]= Option.new(key, options)
    end
    # reads the value for the given key. if on value is defined, raises NoValueError. 
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
    # updates the given key with the given value. 
    def update(key, value)
      key = recognize_key! key
      value = recognized_options[key].validate! value
      @config_hash[key]=value
    end
    # creates a new key and updates it with the given value. options are passed to Option.new. 
    def create_update(key, value, options={})
      create(key, options)
      update(key, value)
    end
    # takes a hash of key/value pairs and calls #update on each pair. 
    def update_hash(hash)
      hash.each do |k,v|
        update(k,v)
      end
    end
    # deletes the given value from the hash. this does not affect any ancestor Configurations. 
    def delete(key)
      key = check_key key
      @config_hash.delete(key)
    end
  end
  # module to be included in anything that should have a #config method representing a Configuration. 
  module Configurable
    # the parent for the Configuration returned from #config 
    attr_accessor :configuration_parent
    # returns a Configuration object 
    def config
      @configuration ||= Configuration.new(configuration_parent)
    end
    private
    # takes a hash of given options, a map of config keys, and a list of other allowed keys. 
    #
    # the keymap is keyed with keys of the options hash and its values are keys of the Configuration
    # returned from #config. 
    #
    # other allowed keys limit what keys are recognized in the given options hash, and ArgumentError
    # is raised if unrecognized keys are present (this is done by #handle_options; see that method's
    # documentation). 
    # 
    # returns a hash in which any defined config keys in the keymap which are not already 
    # defined in the given options are set to their config value. 
    def options_from_config(given_options, keymap, other_allowed_keys = [])
      config_options = (keymap.keys - given_options.keys).inject({}) do |opts, key|
        if given_options.key?(key)
          opts
        elsif config.defined_key?(keymap[key])
          opts.merge(key => config[keymap[key]])
        else
          opts
        end
      end
      handle_options(given_options, config_options, other_allowed_keys + keymap.keys)
    end
  end
  
  @base_configuration=Configuration.new(nil) do |config|
    config.create_update(:attach_timeout, 30, :validator => :numeric)
    config.create(:default_browser, :validator => proc do |val|
      require 'vapir-common/browsers'
      unless (val.is_a?(String) || val.is_a?(Symbol)) && (real_key = Vapir::SupportedBrowsers.keys.detect{|key| key.to_s==val.to_s })
        raise ArgumentError, "default_browser should be a string or symbol matching a supported browser - one of: #{Vapir::SupportedBrowsers.keys.join(', ')}. instead got #{value.inspect}"
      end
      real_key
    end)
    config.create_update(:highlight_color, 'yellow')
    config.create_update(:wait, true, :validator => :boolean)
    config.create_update(:type_keys, false, :validator => :boolean)
    config.create_update(:typing_interval, 0, :validator => :numeric)
  end
  
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
