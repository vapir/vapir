module Watir
  def self.fuzzy_match(attr, what)
    case what
    when String, Symbol
      case attr
      when String, Symbol
        attr.to_s.downcase.strip==what.to_s.downcase.strip
      else
        attr==what
      end
    when Regexp
      case attr
      when Regexp
        attr==what
      else
        attr =~ what
      end
    else
      attr==what
    end
  end
end
module Watir
  module Container
  end
  module Document
  end
  module Frame
  end
  module Element
  end
  module NonControlElement
  end
  module InputElement
  end
  module RadioCheckCommon
  end
  module TextField
  end
  module Hidden
  end
  module Button
  end
  module FileField
  end
  module Option
  end
  module SelectList
  end
  module Radio
  end
  module CheckBox
  end
  module Form
  end
  module Table
  end
  module TableRow
  end
  module TableCell
  end
  module Link
  end
end
