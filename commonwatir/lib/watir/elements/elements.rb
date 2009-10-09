require 'watir/elements/element'

module Watir
  module Container
  end
  module Document
  end
  
  module Frame
    TAG='frame'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
    DefaultHow=:name
  end
  module InputElement
    Specifiers= [ {:tagName => 'input'},
                  {:tagName => 'textarea'},
                  {:tagName => 'button'},
                  {:tagName => 'select'},
                ]
    ContainerSingleMethod=['input', 'input_element']
    ContainerMultipleMethod=['inputs', 'input_elements']
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module TextField
    Specifiers= [ {:tagName => 'textarea'},
                  {:tagName => 'input', :types => ['text', 'textarea','password','hidden']},
                ]
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Hidden
    Specifiers=[{:tagName => 'input', :type => 'hidden'}]
    include ContainerMethodsFromName
    DefaultHow=:name
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Button
    Specifiers=[ {:tagName => 'input', :types => ['button', 'submit', 'image', 'reset']}, 
                 {:tagName => 'button'}
               ]
    include ContainerMethodsFromName
    DefaultHow=:value
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module FileField
    Specifiers=[{:tagName => 'input', :type => 'file'}]
    include ContainerMethodsFromName
    DefaultHow=:name
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Option
    TAG='option'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module SelectList
    TAG='select'
    ContainerSingleMethod=['select_list', 'select']
    ContainerMultipleMethod=['select_lists', 'selects']
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Radio
    Specifiers=[{:tagName => 'input', :type => 'radio'}]
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module CheckBox
    Specifiers=[{:tagName => 'input', :type => 'checkbox'}]
    ContainerSingleMethod=['checkbox', 'check_box']
    ContainerMultipleMethod=['checkboxes', 'check_boxes']
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Form
    TAG='form'
    include ContainerMethodsFromName
    DefaultHow=:name
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Image
    TAG = 'IMG'
    include ContainerMethodsFromName
    DefaultHow=:name
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Table
    TAG = 'TABLE'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module TableRow
    TAG='tr'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module TableCell
    TAG='td'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Link
    TAG = 'A'
    ContainerSingleMethod=['a', 'link']
    ContainerMultipleMethod=['as', 'links']
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Pre
    TAG = 'PRE'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module P
    TAG = 'P'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Div
    TAG = 'DIV'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Span
    TAG = 'SPAN'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Strong
    TAG = 'STRONG'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Label
    TAG = 'LABEL'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Ul
    TAG = 'UL'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Li
    TAG = 'LI'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Dl
    TAG = 'DL'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Dt
    TAG = 'DT'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Dd
    TAG = 'DD'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module H1
    TAG = 'H1'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module H2
    TAG = 'H2'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module H3
    TAG = 'H3'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module H4
    TAG = 'H4'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module H5
    TAG = 'H5'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module H6
    TAG = 'H6'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Map
    TAG = 'MAP'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Area
    TAG = 'AREA'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module TBody
    TAG = 'TBODY'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
  module Em
    TAG = 'EM'
    include ContainerMethodsFromName
    include SetContainerMethodsOnInheritandCopyConstants
  end
end
