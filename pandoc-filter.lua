-- Convert a <span role="cite" data-bibkey="foo"> to a \ref{foo}
function Span(elem)
  attrs = elem.attr.attributes
  if attrs.role  == "cite" then
    return pandoc.Cite("", {
      pandoc.Citation(attrs.bibkey, "NormalCitation", {}, {}, 0, 0)
    })
  end
end
