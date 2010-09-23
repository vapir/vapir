module Vapir
  SupportedBrowsers = {
    :ie => {:class_name => 'Vapir::IE', :require => 'vapir-ie', :gem => 'vapir-ie'},
    :firefox => {:class_name => 'Vapir::Firefox', :require => 'vapir-firefox', :gem => 'vapir-firefox'},
  }
  SupportedBrowsers.each do |key, browser_hash|
    # set up autoload
    split_class = browser_hash[:class_name].split('::')
    class_namespace = split_class[0..-2].inject(Object) do |namespace, name_part|
      namespace.const_get(name_part)
    end
    class_namespace.autoload(split_class.last, browser_hash[:require])
    
    # activate the right gem + version
    begin
      require 'rubygems'
      gem browser_hash[:gem], "=#{Vapir::Common::VERSION}"
    rescue LoadError
    end
  end
end
