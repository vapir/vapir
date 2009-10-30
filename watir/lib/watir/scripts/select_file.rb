at_exit do
  if $!
    err={:class => $!.class, :message => $!.message, :backtrace => $!.backtrace}
    if $upload_dialog && $upload_dialog.exists? 
      # if the upload dialog still exists, we need to close it so that the #click WIN32OLE call in the parent process can return. 
      if (upload_dialog_popup=$upload_dialog.enabled_popup)
        # we will assume this popup is of the "The above file name is invalid" variety, so click 'OK'
        contents=begin
          upload_dialog_popup.children.select{|child| child.class_name=='Static' && child.text!=''}.map{|child| child.text}.join(' ')
        rescue WinWindow::Error
          "{Unable to retrieve contents}"
        end
        err[:message]+="\n\nA popup was found on the dialog with title: \n#{upload_dialog_popup.text.inspect}\nand text contents: \n#{contents}"
        if upload_dialog_popup.click_child_button_try_for!('OK', 4, :exception => nil)
          err[:message]+="\n\nClicked 'OK' on the popup."
        end
      end
      # once the popup is gone (or if there wasn't one - this happens if the field was set to blank, or set to a directory that exists)
      # then click 'cancel' 
      if $upload_dialog.click_child_button_try_for!('Cancel', 4, :exception => nil)
        err[:message]+="\n\nClicked the 'Cancel' button instead of 'Open' on the File Upload dialog."
      end
      
      # none of the above are expected to error, but maybe should be in a begin/rescue just in case?
    end
    if $error_file_name && $error_file_name != ''
      File.open($error_file_name, 'w') do |error_file|
        to_write=Marshal.dump(err)
        error_file.write(to_write)
      end
    end
  else
    if $error_file_name && $error_file_name != '' && File.exists?($error_file_name)
      File.delete($error_file_name)
      # the file not existing indicates success. 
    end
  end
end

$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'commonwatir', 'lib'))

require 'watir/win_window'
require 'watir/waiter'
require 'watir/exceptions'

browser_hwnd, file_path, $error_file_name=*ARGV
unless (2..3).include?(ARGV.size) && browser_hwnd =~ /^\d+$/ && browser_hwnd.to_i > 0
  raise ArgumentError, "This script takes two or three arguments: the hWnd that the File Selection dialog will pop up on (positive integer); the path to the file to select; and (optional) a filename to write any failure message to."
end

# titles of file upload window titles in supported browsers 
# Add to this titles in other languages, too 
UploadWindowTitles= { :IE8 => "Choose File to Upload", 
                      :IE7 => 'Choose file', 
                    }
# list of arguments to give to WinWindow#child_control_with_preceding_label to find the filename field
# on dialogs of supported browsers (just the one right now because it's the same in ie7 and ie8)
# add to this stuff for other languages, too 
UploadWindowFilenameFields = [["File &name:", {:control_class_name => 'ComboBoxEx32'}]]

browser_window=WinWindow.new(browser_hwnd.to_i)

popup=nil
$upload_dialog=::Waiter.try_for(16, :exception => nil) do
  if (popup=browser_window.enabled_popup) && UploadWindowTitles.values.include?(popup.text)
    popup
  end
end
unless $upload_dialog
  raise Watir::Exception::NoMatchingWindowFoundException.new('No window found to upload a file - '+(popup ? "enabled popup exists but has unrecognized text #{popup.text}" : 'no popup is on the browser'))
end
filename_fields=UploadWindowFilenameFields.map do |control_args|
  $upload_dialog.child_control_with_preceding_label(*control_args)
end
unless (filename_field=filename_fields.compact.first)
  raise Watir::Exception::NoMatchingWindowFoundException, "Could not find a filename field in the File Upload dialog"
end
filename_field.send_set_text! file_path
$upload_dialog.click_child_button_try_for!('Open', 4, :exception => WinWindow::Error.new("Failed to click the Open button on the File Upload dialog. It exists, but we couldn't click it."))
