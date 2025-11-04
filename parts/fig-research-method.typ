#import "data.typ"
#import "colors.typ": colors

#figure(caption: [Overview of research method], {
  import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge, shapes
  let r = data.reprod_files.pairs().map(((n, v)) => (n, raw(lang: "yml", v.id + "." + v.ext))).to-dict()

  let start(name, ..args) = node(radius: 1em, name: name, ..args)
  let end(name, ..args) = node(radius: 1em, fill: black, name: name, ..args)

  let procedure(name, ..args) = node(
    shape: shapes.hexagon,
    fill: colors.at(0),
    name: name,
  ..args)
  let source(name, ..args) = node(
    shape: shapes.cylinder,
    fill: colors.at(1),
    name: name,
  ..args)
  let manual_procedure(name, ..args) = node(
    shape: shapes.octagon,
    fill: colors.at(2),
    name: name,
  ..args)
  let artifact(name, ..args) = node(
    shape: shapes.rect,
    fill: colors.at(3).lighten(20%),
    name: name,
  ..args)

  let group(color: blue, name, label, ..args) = {
    node(
      snap: false,
      inset: 0.5em,
      stroke: color.darken(20%).saturate(50%),
      fill: color.lighten(50%),
      text(color.darken(50%).saturate(80%), place(top, dy: -1.6em, label)),
      name: name,
    ..args)
  }

  scale(67%, reflow: true, diagram(
    spacing: (1.6mm, 2.2mm),
    node-stroke: 1pt,

    // Key
    node((0,-3), stroke: none)[Key:],
    manual_procedure(<key-manual-procedure>, (0.75, -3))[Manual Procedure],
    procedure(<key-automated-procedure>, (1.88, -3))[Automated Procedure],
    artifact(<key-artifact>, (2.75, -3))[Artifact],
    source(<key-source>, (3.40, -2.9))[Source],

    start(<start>, (1,-1)),
    edge(<build-search-query>, "-|>"),

    manual_procedure(<build-search-query>, (1,0))[Build Search Query],
    edge("-|>"),
    artifact(<query-string>, (2,0))[Query String\ #r.scopus_search_query],
    edge(<database-search>, "-|>"),

    source(<scopus>, (0,1))[Scopus],
    edge("-|>"),
    procedure(<database-search>, (1,1))[Database Search\ #link("https://scopus.com")],
    edge("-|>"),
    artifact(<abstracts>, (2,1))[*#data.scopus_results.len()* abstracts\ #r.scopus_search_results],
    edge(<sampling>, "-|>"),
    edge(<llm-extraction>, "-|>", bend: 5deg),

    procedure(<llm-extraction>, (1,2))[LLM Extraction\ #r.llm_extraction_script],
    edge("-|>"),
    artifact(<extracted-tools>, (2,2))[*#data.llm_extracted_tools.len()* tools\ #r.llm_extraction_results],
    edge(<tool-selection>, "-|>", bend: 5deg),
    edge(<validate-llm>, "-|>"),

    manual_procedure(<tool-selection>, (1,3))[Tool Selection],
    edge(<tool-selection>, <selected-tools>, "-|>"),
    artifact(<selected-tools>, (2,3))[*#data.tools_selected.len()* tools\ #r.tool_selection_manual],
    edge(<keyword-match>, "-|>", bend: 5deg),

    source(<code-repositories>, (0,4))[Source Code \ Repositories],
    edge("-|>"),
    procedure(<keyword-match>, (1,4))[Code matching\ #r.tool_code_ocurrences_script],
    edge("-|>"),
    artifact(<tool-relations>, (2,4))[Tool relations\ #r.tool_code_ocurrences_result],

    // Outputs section
    group(<artifacts>, [Outputs], enclose: (<query-string>, <abstracts>, <extracted-tools>, <selected-tools>, <tool-relations>), color: colors.at(7)),

    // Validation section
    procedure(<sampling>, (3,0))[Sampling \ #r.validation_set_script],
    edge("-|>"),
    artifact(<validation-abstracts>, (3,1))[*#data.validation_set_results.len()* abstracts \ #r.validation_set_results],
    edge("-|>"),
    manual_procedure(<labeling>, (3,2))[Sample Labeling],
    edge("-|>"),
    artifact(<validation-tools>, (3,3))[*#data.validation_set_tools.len()* tools \ #r.validation_set_results],
    edge("-|>"),
    manual_procedure(<validate-llm>, (3,4))[Validate Extraction],
    group(<validation>, [Validation], color: colors.at(4), enclose: (<sampling>, <validation-abstracts>, <labeling>, <validation-tools>, <validate-llm>)),
    edge(<validation.south>, <reporting>, "-|>"),

    edge(<artifacts>, <reporting>, "-|>"),
    manual_procedure(<reporting>, (2,6))[Reporting],
    edge(<end>, "-|>"),

    end(<end>, (1,6))
  ))
}) <fig-research-method>
