module Watir

  class IEPre < IEElement
    include Pre
  end

  class IEP < IEElement
    include P
  end

  # this class is used to deal with Div tags in the html page. http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/div.asp?frame=true
  # It would not normally be created by users
  class IEDiv < IEElement
    include Div
  end

  # this class is used to deal with Span tags in the html page. It would not normally be created by users
  class IESpan < IEElement
    include Span
  end

  class IEMap < IEElement
    include Map
  end

  class IEArea < IEElement
    include Area
  end

  # Accesses Label element on the html page - http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/label.asp?frame=true
  class IELabel < IEElement
    include Label
  end

  class IELi < IEElement
    include Li
  end
  class IEUl < IEElement
    include Ul
  end
  class IEOl < IEElement
    include Ol
  end
  class IEH1 < IEElement
    include H1
  end
  class IEH2 < IEElement
    include H2
  end
  class IEH3 < IEElement
    include H3
  end
  class IEH4 < IEElement
    include H4
  end
  class IEH5 < IEElement
    include H5
  end
  class IEH6 < IEElement
    include H6
  end
  class IEDl < IEElement
    include Dl
  end
  class IEDt < IEElement
    include Dt
  end
  class IEDd < IEElement
    include Dd
  end
  class IEStrong < IEElement
    include Strong
  end
  class IEEm < IEElement
    include Em
  end
end