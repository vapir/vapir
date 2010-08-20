require(File.join(File.dirname(__FILE__),'vapir-common/lib/vapir-common/external/core_extensions.rb'))

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
