module Watir

  class IE::Pre < IE::Element
    include Watir::Pre
  end

  class IE::P < IE::Element
    include Watir::P
  end

  # this class is used to deal with Div tags in the html page. http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/div.asp?frame=true
  # It would not normally be created by users
  class IE::Div < IE::Element
    include Watir::Div
  end

  # this class is used to deal with Span tags in the html page. It would not normally be created by users
  class IE::Span < IE::Element
    include Watir::Span
  end

  class IE::Map < IE::Element
    include Watir::Map
  end

  class IE::Area < IE::Element
    include Watir::Area
  end

  # Accesses Label element on the html page - http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/label.asp?frame=true
  class IE::Label < IE::Element
    include Watir::Label
  end

  class IE::Li < IE::Element
    include Watir::Li
  end
  class IE::Ul < IE::Element
    include Watir::Ul
  end
  class IE::Ol < IE::Element
    include Watir::Ol
  end
  class IE::H1 < IE::Element
    include Watir::H1
  end
  class IE::H2 < IE::Element
    include Watir::H2
  end
  class IE::H3 < IE::Element
    include Watir::H3
  end
  class IE::H4 < IE::Element
    include Watir::H4
  end
  class IE::H5 < IE::Element
    include Watir::H5
  end
  class IE::H6 < IE::Element
    include Watir::H6
  end
  class IE::Dl < IE::Element
    include Watir::Dl
  end
  class IE::Dt < IE::Element
    include Watir::Dt
  end
  class IE::Dd < IE::Element
    include Watir::Dd
  end
  class IE::Strong < IE::Element
    include Watir::Strong
  end
  class IE::Em < IE::Element
    include Watir::Em
  end
end