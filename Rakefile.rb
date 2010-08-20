base = File.dirname(__FILE__)
['vapir-common','vapir-ie','vapir-firefox'].each do |lib|
  libdir = File.join(base, lib, 'lib')
  if File.directory?(libdir) && !$LOAD_PATH.any?{|lp| File.expand_path(lp) == File.expand_path(libdir) }
    $LOAD_PATH.unshift(libdir)
  end
end
require 'vapir-common/external/core_extensions.rb'

desc 'Build rdoc'
task :rdoc do
  load 'vapir-ie/vapir-ie.gemspec'
  load 'vapir-firefox/vapir-firefox.gemspec'
  load 'vapir-common/vapir-common.gemspec'
  exclude = %w(
    vapir-firefox/lib/vapir-firefox/jssh_socket.rb
    vapir-ie/lib/vapir-ie/win32ole/win32ole.c
  )
  rdoc_argvs=[ exclude.map{|file| ['--exclude', file]}.flatten +
    %W(
      --title Vapir\ #{Vapir::Common::VERSION}
      --op vapir_rdoc
    ) + (Vapir::Common::GemSpec.files.map{|f| File.join('vapir-common', f)} +
         Vapir::Firefox::GemSpec.files.map{|f| File.join('vapir-firefox', f)} +
         Vapir::IE::GemSpec.files.map{|f| File.join('vapir-ie', f)} -
         exclude),
    %W(
      --title Vapir-IE\ #{Vapir::IE::VERSION}
      --op vapir_ie_rdoc
      --main Vapir::IE
    ) + (Vapir::Common::GemSpec.files.map{|f| File.join('vapir-common', f)} +
         Vapir::IE::GemSpec.files.map{|f| File.join('vapir-ie', f)} -
         exclude),
    %W(
      --title Vapir-Firefox\ #{Vapir::Firefox::VERSION}
      --op vapir_firefox_rdoc
      --main Vapir::Firefox
    ) + (Vapir::Common::GemSpec.files.map{|f| File.join('vapir-common', f)} +
         Vapir::Firefox::GemSpec.files.map{|f| File.join('vapir-firefox', f)} -
         exclude),
    %w(
      --title JsshObject\ JsshSocket
      --op jssh_rdoc
      --main JsshObject
      vapir-firefox/lib/vapir-firefox/jssh_socket.rb
    ),
  ].map{|argv| %w(-f html  --tab-width 2  --show-hash  --inline-source  --template hanna  --charset=UTF-8)+argv } # these will be common to all of them

  gem 'hanna'
  require 'hanna/version'
  Hanna::require_rdoc
  require 'rdoc/rdoc'
  rdoc_argvs.each do |argv|
    RDoc::RDoc.new.document(argv)
  end
end

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
