base = File.dirname(__FILE__)
['vapir-common','vapir-ie','vapir-firefox'].each do |lib|
  libdir = File.join(base, lib, 'lib')
  if File.directory?(libdir) && !$LOAD_PATH.any?{|lp| File.expand_path(lp) == File.expand_path(libdir) }
    $LOAD_PATH.unshift(libdir)
  end
end
require 'vapir-common/external/core_extensions.rb'

desc "check files for things that appear wrong: not in a gemfile; contains a carriage return; or wrong mode"
task :checkfiles do
  should_be_gemfiles = Dir['vapir-*/lib/**/*']-Dir['vapir-ie/lib/vapir-ie/IEDialog/*'].select(&File.method(:file?))
  are_gemfiles = %w(Common Firefox IE).inject([]) do |files, libname|
    load "vapir-#{libname.downcase}/vapir-#{libname.downcase}.gemspec"
    files + Vapir.const_get(libname)::GemSpec.files.map{|f| File.join("vapir-#{libname.downcase}", f) }
  end
  ycomb do |recurse|
    proc do |dir|
      (Dir.entries(dir || '.')-['.', '..', '.git']).each do |entry|
        file=dir ? File.join(dir, entry) : entry
        if File.directory?(file)
          recurse.call file
        elsif File.file?(file)
          if entry !~ /(\.gif|\.jpg|\.dll|\.so|\.png)$/i && File.read(file).include?("\r")
            STDOUT.puts "\\r in #{file}"
          end
          if should_be_gemfiles.include?(file) && !are_gemfiles.include?(file)
            STDOUT.puts "not in gemspec: #{file}"
          end
          if File.stat(file).mode & 0700 != 0600
            STDOUT.puts "wrong mode: #{file}"
          end
        end
      end
    end
  end.call(nil)
end

desc "Find carriage returns in the current directory"
task :findcr do
  ycomb do |recurse|
    proc do |dir|
      (Dir.entries(dir)-['.', '..', '.git']).each do |entry|
        next if entry =~ /(_rdoc|\.gif|\.jpg|\.dll|\.so|\.png)$/i
        file=File.join(dir, entry)
        if File.directory?(file)
          recurse.call file
        elsif File.file?(file)
          if File.read(file).include?("\r")
            puts "\\r in #{file}"
          end
        end
      end
    end
  end.call('.')
end
