# takes given options and default options, and optionally a list of additional allowed keys not specified in default options
# (this is useful when you want to pass options along to another function but don't want to specify a default that will
# clobber that function's default) 
# raises ArgumentError if the given options have an invalid key (defined as one not
# specified in default options or other_allowed_keys), and sets default values in given options where nothing is set.
def handle_options!(given_options, default_options, other_allowed_keys=[])
  unless (unknown_keys=(given_options.keys-default_options.keys-other_allowed_keys)).empty?
    raise ArgumentError, "Unknown options: #{(given_options.keys-default_options.keys).map(&:inspect).join(', ')}. Known options are #{(default_options.keys+other_allowed_keys).map(&:inspect).join(', ')}"
  end
  (default_options.keys-given_options.keys).each do |key|
    given_options[key]=default_options[key]
  end
  given_options
end
