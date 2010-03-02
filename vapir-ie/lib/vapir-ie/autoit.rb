module Watir
  AutoItDLL=File.join(File.expand_path(File.dirname(__FILE__)),'AutoItX3.dll')
  def self.autoit
    @@autoit||= begin
      begin
        WIN32OLE.new('AutoItX3.Control')
      rescue WIN32OLERuntimeError
        system("regsvr32.exe /s \"#{AutoItDLL.gsub('/', '\\')}\"")
        WIN32OLE.new('AutoItX3.Control')
      end
    end
  end
end
