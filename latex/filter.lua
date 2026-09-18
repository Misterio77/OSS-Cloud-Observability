-- Convert Typst's semantic HTML into an acmart-oriented Pandoc document.

local latex = {}
local authors = {}
local ccs = {}
local keywords = nil

local function has_class(elem, class)
  for _, value in ipairs(elem.classes) do
    if value == class then return true end
  end
  return false
end

local function attribute(elem, name, default)
  return elem.attributes[name] or elem.attributes["data-" .. name] or default
end

local function meta_string(value)
  return pandoc.MetaString(value or "")
end

-- Prose metadata goes through inlines so the LaTeX writer renders punctuation
-- (notably apostrophes) the way it does in the body, rather than escaping it.
local function meta_text(value)
  return pandoc.MetaInlines({pandoc.Str(value or "")})
end

local function trim(value)
  local result = value:gsub("^%s+", ""):gsub("%s+$", "")
  return result
end

local function render_blocks(blocks)
  return trim(pandoc.write(pandoc.Pandoc(blocks), "latex"))
end

local function strip_heading_number(inlines)
  if #inlines > 0 and inlines[1].tag == "Str" then
    local value = inlines[1].text
    if value:match("^%d+[%.%d]*%.?$") or value:match("^[A-Z][%.%d]*%.?$") then
      table.remove(inlines, 1)
      if #inlines > 0 and inlines[1].tag == "Space" then
        table.remove(inlines, 1)
      end
    end
  end
  return inlines
end

local function strip_caption_number(caption)
  local block = caption.long[1]
  local inlines = block and block.content
  local first = inlines and inlines[1]
  if not first or first.tag ~= "Str" then return caption end

  local value = first.text
    :gsub("^Figure[^%d]*%d+:%s*", "")
    :gsub("^Table[^%d]*%d+:%s*", "")
  if value == "" then
    table.remove(inlines, 1)
    if inlines[1] and inlines[1].tag == "Space" then table.remove(inlines, 1) end
  else
    first.text = value
  end
  return caption
end

local function validate_identifier(value, kind)
  if not value:match("^[%w][%w_.:%-]*$") then
    error(kind .. " has an unsafe or missing identifier: " .. value)
  end
  return value
end

local function latex_width(value, basis)
  local percentage = tonumber(value:match("^(%d+%.?%d*)%%$"))
  if not percentage then error("invalid layout width: " .. value) end
  if percentage == 100 then return "\\" .. basis end
  local ratio = string.format("%.4g", percentage / 100):gsub("^0", "")
  return ratio .. "\\" .. basis
end

local function normalize_header(header, appendix)
  local first = header.content[1]
  if appendix and first and first.tag == "Str" and first.text:match("^[A-Z][%.%d]*%.?$") then
    for index, class in ipairs(header.classes) do
      if class == "unnumbered" then
        table.remove(header.classes, index)
        break
      end
    end
  end
  header.level = math.max(1, header.level - 1)
  header.content = strip_heading_number(header.content)
end

local function normalize_headers(block, appendix)
  if block.tag == "Header" then
    normalize_header(block, appendix)
  elseif block.tag == "Div" then
    for _, child in ipairs(block.content) do
      normalize_headers(child, appendix)
    end
  end
end

local function figure_image(figure)
  local images = {}
  figure:walk({Image = function(elem) table.insert(images, elem) end})
  if #images ~= 1 then
    error("acmart-figure requires exactly one image; found " .. #images)
  end
  return images[1]
end

local function materialize_image(image, label)
  validate_identifier(label, "figure")
  local mime, contents = pandoc.mediabag.fetch(image.src)
  if not mime or not contents then error("could not read figure media: " .. image.src) end

  local extension
  if mime == "image/svg+xml" then
    contents = pandoc.pipe("rsvg-convert", {"--format=pdf"}, contents)
    mime = "application/pdf"
    extension = "pdf"
  elseif mime == "application/pdf" then
    extension = "pdf"
  elseif mime == "image/png" then
    extension = "png"
  elseif mime == "image/jpeg" then
    extension = "jpg"
  else
    error("unsupported figure media type: " .. mime)
  end

  local path = label .. "." .. extension
  pandoc.mediabag.insert(path, mime, contents)
  return "assets/" .. path
end

local function render_figure_layout(div)
  local figure = div.content[1]
  if #div.content ~= 1 or not figure or figure.tag ~= "Figure" then
    error("acmart-figure must contain exactly one figure")
  end
  local image = figure_image(figure)

  local span = attribute(div, "span", "false") == "true"
  local width = latex_width(
    attribute(div, "width", "100%"),
    span and "textwidth" or "columnwidth"
  )
  local environment = span and "figure*" or "figure"
  local placement = span and "t" or "H"
  local path = materialize_image(image, figure.identifier)
  local caption = render_blocks(figure.caption.long)

  -- ACM requires an accessibility description for every image.
  local description = attribute(div, "description", "")
  if description == "" then
    error("acmart-figure requires a description: " .. figure.identifier)
  end
  description = render_blocks({pandoc.Plain({pandoc.Str(description)})})

  return pandoc.RawBlock("latex", table.concat({
    "\\begin{" .. environment .. "}[" .. placement .. "]",
    "\\centering",
    "\\includegraphics[width=" .. width .. "]{" .. path .. "}",
    "\\caption{" .. caption .. "}\\label{" .. figure.identifier .. "}",
    "\\Description{" .. description .. "}",
    "\\end{" .. environment .. "}",
  }, "\n"))
end

local function table_body_rows(value)
  local rows = pandoc.List()
  for _, body in ipairs(value.bodies) do
    rows:extend(body.head)
    rows:extend(body.body)
  end
  rows:extend(value.foot.rows)
  return rows
end

local function render_rows(rows, columns, lines)
  for _, row in ipairs(rows) do
    if #row.cells ~= #columns then
      error("table row has " .. #row.cells .. " cells for " .. #columns .. " columns")
    end
    local cells = {}
    for _, cell in ipairs(row.cells) do
      if (cell.row_span or 1) ~= 1 or (cell.col_span or 1) ~= 1 then
        error("row-spanning and column-spanning table cells are unsupported")
      end
      table.insert(cells, render_blocks(cell.contents))
    end
    table.insert(lines, table.concat(cells, " & ") .. " \\\\")
  end
end

local function render_table_layout(div)
  local blocks = pandoc.List()
  local value = nil
  for _, block in ipairs(div.content) do
    if block.tag == "Table" then
      value = block
    else
      blocks:insert(block)
    end
  end
  if not value then error("acmart-table must contain a table") end

  local columns = attribute(div, "columns", ""):gsub("%s+", "")
  if columns == "" then columns = string.rep("X", #value.colspecs) end
  if columns:find("[^lcrX]") then error("invalid table columns: " .. columns) end

  local size = attribute(div, "size", "small")
  local valid_sizes = {
    tiny = true, scriptsize = true, footnotesize = true,
    small = true, normalsize = true,
  }
  if not valid_sizes[size] then error("invalid table size: " .. size) end

  local width = latex_width(attribute(div, "width", "100%"), "columnwidth")
  local lines = {"\\toprule"}
  render_rows(value.head.rows, columns, lines)
  if #value.head.rows > 0 then table.insert(lines, "\\midrule") end
  render_rows(table_body_rows(value), columns, lines)
  table.insert(lines, "\\bottomrule")

  local label = ""
  if value.identifier ~= "" then
    label = "\\label{" .. validate_identifier(value.identifier, "table") .. "}"
  end

  blocks:insert(pandoc.RawBlock("latex", table.concat({
    "\\begin{table}[!htbp]",
    "\\centering",
    "\\caption{" .. render_blocks(value.caption.long) .. "}",
    label,
    "\\" .. size,
    "\\begin{tabularx}{" .. width .. "}{@{}" .. columns .. "@{}}",
    table.concat(lines, "\n"),
    "\\end{tabularx}",
    "\\end{table}",
  }, "\n")))
  return blocks
end

-- Returns a list of blocks: a layout div may expand to several.
local function render_layout(block)
  if block.tag == "Div" and has_class(block, "latex-figure-layout") then
    return pandoc.List({render_figure_layout(block)})
  end
  if block.tag == "Div" and has_class(block, "latex-table-layout") then
    return render_table_layout(block)
  end
  return pandoc.List({block})
end

function Str(elem)
  elem.text = elem.text:gsub("′", "'")
  return elem
end

-- Long identifiers and paths are unbreakable in typewriter text, which
-- overflows acmart's narrow columns. Allow breaks after their separators
-- without letting TeX hyphenate the words themselves.
function Code(elem)
  local rendered = trim(pandoc.write(pandoc.Pandoc({pandoc.Plain({elem})}), "latex"))
  return pandoc.RawInline("latex", (rendered:gsub("([%-%.,/_])", "%1\\allowbreak{}")))
end

function Span(elem)
  local attrs = elem.attributes
  local key = attrs.bibkey or attrs["data-bibkey"]

  if attrs.role == "cite" and key then
    return pandoc.Cite(elem.content, {
      pandoc.Citation(key, "NormalCitation", {}, {}, 0, 0)
    })
  end

  if attrs.role == "typst-footnote" then
    return pandoc.Note({pandoc.Plain(elem.content)})
  end

end

function Link(elem)
  local id = elem.target:match("^#(.+)$")
  if not id then return nil end

  local prefix = "Section"
  if id:match("^fig%-") then
    prefix = "Figure"
  elseif id:match("^table%-") then
    prefix = "Table"
  end

  return pandoc.RawInline("latex", prefix .. "~\\ref{" .. id .. "}")
end

function Figure(elem)
  elem.caption = strip_caption_number(elem.caption)

  if #elem.content == 1 and elem.content[1].tag == "Table" then
    local value = elem.content[1]
    value.caption = elem.caption
    value.attr = elem.attr
    return value
  end

  return elem
end

function Header(elem)
  local first = elem.content[1]
  local numbered = first and first.tag == "Str" and first.text:match("^%d+[%.%d]*%.?$")
  if not numbered then elem.classes:insert("unnumbered") end
  return elem
end

function Div(elem)
  if elem.attributes.role == "doc-bibliography" then
    return {}
  end

  if has_class(elem, "latex-meta") then
    latex.title = elem.attributes.title or elem.attributes["data-title"]
    latex.doi = (elem.attributes.doi or ""):gsub("^https?://doi%.org/", "")
    latex.isbn = elem.attributes.isbn
    latex.copyright = elem.attributes.copyright
    latex.cc_type = attribute(elem, "cc-type", "")
    latex.short_authors = attribute(elem, "short-authors", "")
    latex.conference_name = elem.attributes["conference-name"]
    latex.conference_short = elem.attributes["conference-short"]
    latex.conference_date = elem.attributes["conference-date"]
    latex.conference_year = elem.attributes["conference-year"]
    latex.conference_venue = elem.attributes["conference-venue"]
    latex.conference_booktitle = attribute(elem, "conference-booktitle", "")

    elem:walk({
      Span = function(author)
        if not has_class(author, "latex-author") then return nil end
        local location = author.attributes.city or ""
        local city, country = location:match("^(.*),%s*([^,]+)$")
        table.insert(authors, {
          name = pandoc.MetaInlines(author.content),
          email = meta_string(author.attributes.email),
          institute = meta_string(author.attributes.institute),
          city = meta_string(city or location),
          country = meta_string(country or ""),
        })
      end
    })
    return {}
  end

  if has_class(elem, "latex-ccs") then
    elem:walk({
      Span = function(concept)
        if not has_class(concept, "latex-ccs-concept") then return nil end
        table.insert(ccs, {
          generic = concept.attributes.generic or "",
          specific = concept.attributes.specific or "",
          id = attribute(concept, "id", ""),
          significance = attribute(concept, "significance", "500"),
        })
      end
    })
    return {}
  end

  if has_class(elem, "latex-keywords") then
    keywords = elem.attributes.keywords
    return {}
  end

  if has_class(elem, "latex-callout") then
    local blocks = pandoc.List({pandoc.RawBlock("latex", "\\acmartcallout{%")})
    blocks:extend(elem.content)
    blocks:insert(pandoc.RawBlock("latex", "}"))
    return blocks
  end
end

function Pandoc(doc)
  doc.meta["latex-title"] = meta_text(latex.title)
  doc.meta["latex-doi"] = meta_string(latex.doi)
  doc.meta["latex-isbn"] = meta_string(latex.isbn)
  doc.meta["latex-copyright"] = meta_string(latex.copyright)
  doc.meta["latex-cc-type"] = meta_string(latex.cc_type)
  doc.meta["latex-short-authors"] = meta_text(latex.short_authors)
  doc.meta["latex-conference-name"] = meta_text(latex.conference_name)
  doc.meta["latex-conference-short"] = meta_text(latex.conference_short)
  doc.meta["latex-conference-date"] = meta_text(latex.conference_date)
  doc.meta["latex-conference-year"] = meta_string(latex.conference_year)
  doc.meta["latex-conference-venue"] = meta_text(latex.conference_venue)
  doc.meta["latex-conference-booktitle"] = meta_text(latex.conference_booktitle)
  doc.meta["latex-authors"] = pandoc.MetaList(authors)
  -- ACM's CCSXML block must survive verbatim: a wrapped <concept_desc> would
  -- put a newline inside the description text.
  local concepts = pandoc.List()
  local xml = pandoc.List({"\\begin{CCSXML}", "<ccs2012>"})
  for _, concept in ipairs(ccs) do
    concepts:insert({
      generic = meta_string(concept.generic),
      specific = meta_string(concept.specific),
      significance = meta_string(concept.significance),
    })
    xml:extend({
      "<concept>",
      "<concept_id>" .. concept.id .. "</concept_id>",
      "<concept_desc>" .. concept.generic .. "~" .. concept.specific .. "</concept_desc>",
      "<concept_significance>" .. concept.significance .. "</concept_significance>",
      "</concept>",
    })
  end
  xml:extend({"</ccs2012>", "\\end{CCSXML}"})

  doc.meta["latex-ccs"] = pandoc.MetaList(concepts)
  if #ccs > 0 then
    doc.meta["latex-ccsxml"] = pandoc.MetaBlocks({
      pandoc.RawBlock("latex", table.concat(xml, "\n"))
    })
  end
  doc.meta["latex-keywords"] = meta_text(keywords)

  local output = {}
  local abstract = {}
  local acknowledgments = {}
  local appendix = {}
  local mode = "body"

  local function append_block(destination, block, is_appendix)
    normalize_headers(block, is_appendix)
    for _, rendered in ipairs(render_layout(block)) do
      table.insert(destination, rendered)
    end
  end

  for _, block in ipairs(doc.blocks) do
    if block.tag == "Div" and has_class(block, "latex-appendix") then
      table.insert(appendix, pandoc.RawBlock("latex", "\\appendix"))
      for _, child in ipairs(block.content) do
        append_block(appendix, child, true)
      end
    elseif block.tag == "Header" and block.identifier == "abstract" then
      mode = "abstract"
    elseif block.tag == "Header" and block.identifier == "acknowledgments" then
      mode = "acknowledgments"
    elseif block.tag == "Header" and block.identifier == "references" then
      mode = "references"
    elseif block.tag == "Header" then
      if mode == "abstract" then mode = "body" end
      if mode == "acknowledgments" then mode = "body" end
      if mode == "body" then append_block(output, block, false) end
    elseif mode == "abstract" then
      table.insert(abstract, block)
    elseif mode == "acknowledgments" then
      table.insert(acknowledgments, block)
    elseif mode == "body" then
      append_block(output, block, false)
    end
  end

  doc.meta.abstract = pandoc.MetaBlocks(abstract)
  doc.meta["latex-acknowledgments"] = pandoc.MetaBlocks(acknowledgments)
  doc.meta["latex-appendix"] = pandoc.MetaBlocks(appendix)
  doc.blocks = output
  return doc
end
