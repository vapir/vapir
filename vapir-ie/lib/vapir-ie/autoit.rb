module Vapir
  AutoItDLL=File.join(File.expand_path(File.dirname(__FILE__)),'AutoItX3.dll')
  # returns a WIN32OLE for an AutoIt control. if AutoIt is not registered, this will attempt to 
  # registered the bundled AutoIt DLL and return a WIN32OLE for it when it is registered. 
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
