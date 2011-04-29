base = File.dirname(__FILE__)
['vapir-common','vapir-ie','vapir-firefox'].each do |lib|
  libdir = File.join(base, lib, 'lib')
  if File.directory?(libdir) && !$LOAD_PATH.any?{|lp| File.expand_path(lp) == File.expand_path(libdir) }
    $LOAD_PATH.unshift(libdir)
  end
end
require 'vapir-common/external/core_extensions.rb'

def rdoc(hash)
  default_stuff = {:format => 'html', :"tab-width" => 2, :"show-hash" => nil, :"inline-source" => nil, :template => 'hanna', :charset => 'UTF-8'}
  hash = default_stuff.merge(hash)
#  STDOUT.puts hash.inspect
  options = (hash.keys-[:files]).inject([]) do |list, key|
    value = hash[key]
    ddkey="--#{key}"
    list + case value
    when nil
      [ddkey]
    when Array
      value.inject([]){|vlist, value_part| vlist+[ddkey, value_part.to_s]}
    else
      [ddkey, value.to_s]
    end
  end
  options+=(hash[:files] || [])
#  STDOUT.puts options.inspect
  if hash[:op] && File.exists?(hash[:op])
    require 'fileutils'
    FileUtils.rm_r(hash[:op])
  end

  gem 'hanna'
  require 'hanna/version'
  Hanna::require_rdoc
  require 'rdoc/rdoc'
  RDoc::RDoc.new.document(options)
end

def common_files
  @common_files ||= begin
    load 'vapir-common/vapir-common.gemspec'
    Vapir::Common::GemSpec.files.map{|f| File.join('vapir-common', f)}
  end
end
def ie_files
  @ie_files ||= begin
    load 'vapir-ie/vapir-ie.gemspec'
    Vapir::IE::GemSpec.files.map{|f| File.join('vapir-ie', f)}
  end
end
def ff_files
  @ff_files ||= begin
    load 'vapir-firefox/vapir-firefox.gemspec'
    Vapir::Firefox::GemSpec.files.map{|f| File.join('vapir-firefox', f)}
  end
end
def exclude
  @exclude ||= %w(
    vapir-firefox/lib/vapir-firefox/jssh_socket.rb
    vapir-ie/lib/vapir-ie/win32ole/win32ole.c
  )
end

desc 'Build all rdoc'
task :rdoc => [:vapir_rdoc, :vapir_ie_rdoc, :vapir_ff_rdoc, :jssh_rdoc]
desc 'Build Vapir rdoc'
task :vapir_rdoc do
  require 'vapir-common/version'
  rdoc(:op => 'vapir_rdoc', :title => "Vapir #{Vapir::Common::VERSION}", :files => (common_files + ie_files + ff_files).select{|file| file =~ /\.rb$/ } - exclude, :exclude => exclude)
end
desc 'Build Vapir-IE rdoc'
task :vapir_ie_rdoc do
  require 'vapir-ie/version'
  rdoc(:op => 'vapir_ie_rdoc', :title => "Vapir-IE #{Vapir::IE::VERSION}", :files => (common_files + ie_files).select{|file| file =~ /\.rb$/ } - exclude, :exclude => exclude)
end
desc 'Build Vapir-Firefox rdoc'
task :vapir_ff_rdoc do
  require 'vapir-firefox/version'
  rdoc(:op => 'vapir_ff_rdoc', :title => "Vapir-Firefox #{Vapir::Firefox::VERSION}", :files => (common_files + ff_files).select{|file| file =~ /\.rb$/ } - exclude, :exclude => exclude)
end
desc 'Build JsshObject, JsshSocket rdoc'
task :jssh_rdoc do
  rdoc(:op => 'jssh_rdoc', :title => 'JsshObject JsshSocket', :main => 'JsshObject', :files => ['vapir-firefox/lib/vapir-firefox/jssh_socket.rb'])
end

desc "check files for things that appear wrong: not in a gemfile; contains a carriage return; or wrong mode"
task :checkfiles do
  should_be_gemfiles = Dir['vapir-*/lib/**/*']-Dir['vapir-ie/lib/vapir-ie/IEDialog/*'].select(&File.method(:file?))
  are_gemfiles = common_files + ff_files + ie_files
  are_gemfiles.reject{|gf| File.exists?(gf) }.each do |missing|
    STDOUT.puts "missing gemfile: #{missing.inspect}"
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
