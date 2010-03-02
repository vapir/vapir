module Vapir

  class IE::Pre < IE::Element
    include Vapir::Pre
  end

  class IE::P < IE::Element
    include Vapir::P
  end

  # this class is used to deal with Div tags in the html page. http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/div.asp?frame=true
  # It would not normally be created by users
  class IE::Div < IE::Element
    include Vapir::Div
  end

  # this class is used to deal with Span tags in the html page. It would not normally be created by users
  class IE::Span < IE::Element
    include Vapir::Span
  end

  class IE::Map < IE::Element
    include Vapir::Map
  end

  class IE::Area < IE::Element
    include Vapir::Area
  end

  # Accesses Label element on the html page - http://msdn.microsoft.com/workshop/author/dhtml/reference/objects/label.asp?frame=true
  class IE::Label < IE::Element
    include Vapir::Label
  end

  class IE::Li < IE::Element
    include Vapir::Li
  end
  class IE::Ul < IE::Element
    include Vapir::Ul
  end
  class IE::Ol < IE::Element
    include Vapir::Ol
  end
  class IE::H1 < IE::Element
    include Vapir::H1
  end
  class IE::H2 < IE::Element
    include Vapir::H2
  end
  class IE::H3 < IE::Element
    include Vapir::H3
  end
  class IE::H4 < IE::Element
    include Vapir::H4
  end
  class IE::H5 < IE::Element
    include Vapir::H5
  end
  class IE::H6 < IE::Element
    include Vapir::H6
  end
  class IE::Dl < IE::Element
    include Vapir::Dl
  end
  class IE::Dt < IE::Element
    include Vapir::Dt
  end
  class IE::Dd < IE::Element
    include Vapir::Dd
  end
  class IE::Strong < IE::Element
    include Vapir::Strong
  end
  class IE::Em < IE::Element
    include Vapir::Em
  end
end