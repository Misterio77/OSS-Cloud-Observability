#import "data.typ"
#import "colors.typ": colors

#show: it => context {
  if "standalone" in sys.inputs {
    set page(height: auto, width: auto, margin: 0cm)
    set text(font: "Linux Libertine O", size: 9pt)
    it
  } else {
    it
  }
}

#{
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

  let group(color: blue, transparentize: 0%, name, label, ..args) = {
    node(
      snap: false,
      inset: 0.5em,
      stroke: color.darken(20%).saturate(50%),
      fill: color.lighten(50%).transparentize(transparentize),
      text(color.darken(50%).saturate(80%), {
        place(top + left, label)
      }),
      name: name,
    ..args)
  }

  scale(70%, reflow: true, diagram(
    spacing: (3mm, 2mm),
    node-stroke: 1pt,

    // Key
    node((-1, -4), stroke: none)[Key:],
    source(<key-source>, (0, -4))[Source],
    manual_procedure(<key-manual-procedure>, (0.7, -4))[Manual Step],
    procedure(<key-automated-procedure>, (1.6,-4))[Automated Step],
    artifact(<key-artifact>, (2.4, -4))[Artifact],

    start(<start>, (1,-2)),
    edge("-|>"),

    // Search phase
    manual_procedure(<build-search-query>, (1,0))[Search query creation],
    edge("-|>"),
    artifact(<query-string>, (2,0))[Query String\ #r.scopus_search_query],
    edge(<database-search>, "-|>"),
    source(<scopus>, (0,0.95))[Scopus],
    edge("-|>"),
    procedure(<database-search>, (1,0.95))[Database search],
    edge("-|>"),
    artifact(<abstracts>, (2,0.95))[*#data.scopus_results.len()* abstracts\ #r.scopus_search_results],
    edge(<abstracts>, <sampling>, "-|>"),
    edge(<llm-extraction>, "-|>"),
    group(<search-phase>, [Search \ Phase], color: colors.at(5), enclose: ((-1, 0.95), <scopus>, <build-search-query>, <query-string>, <database-search>, <abstracts>, (3, 0))),

    // Extraction phase
    procedure(<llm-extraction>, (1,2))[LLM extraction\ #r.llm_extraction_script],
    edge("-|>"),
    artifact(<extracted-tools>, (2,2))[*#data.llm_extracted_tools.len()* tools\ #r.llm_extraction_results],
    edge(<tool-selection>, "-|>"),
    edge(<extracted-tools>, <validate-llm>, "-|>"),
    group(<extraction-phase>, [Extraction \ Phase], color: colors.at(2), enclose: ((-1, 2), <llm-extraction>, <extracted-tools>, (3,2))),

    // Selection phase
    manual_procedure(<tool-selection>, (1,3))[Manual tool selection],
    edge(<tool-selection>, <selected-tools>, "-|>"),
    artifact(<selected-tools>, (2,3))[*#data.tools_selected.len()* tools\ #r.tool_selection_manual],
    edge(<keyword-match>, "-|>"),
    group(<selection-phase>, [Selection \ Phase], color: colors.at(4), enclose: ((-1, 3), <tool-selection>, <selected-tools>, (3,3))),

    // Analysis phase
    source(<code-repositories>, (0.1,4))[Code],
    edge("-|>"),
    procedure(<keyword-match>, (1,4))[Code matching\ #r.tool_code_ocurrences_script],
    edge("-|>"),
    artifact(<tool-relations>, (2,4))[Tool relations\ #r.tool_code_ocurrences_result],
    group(<analysis-phase>, [Analysis \ Phase], color: colors.at(7), enclose: ((-1, 4), <code-repositories>, <keyword-match>, <tool-relations>, (3,4))),

    // Validation phase
    procedure(<sampling>, (3.2,1))[Sampling \ #r.validation_set_script],
    edge("-|>"),
    manual_procedure(<labeling>, (3.2,2))[Manual extraction],
    edge("-|>"),
    artifact(<validation-set>, (3.2,3))[*#data.validation_set_results.len()* abstracts \ *#data.validation_set_tools.len()* tools \ #r.validation_set_results],
    edge("-|>"),
    manual_procedure(<validate-llm>, (3.2,4))[Compare extractions],
    group(<validation-phase>, [Validation], color: colors.at(1), enclose: ((3.2,-0.73), <sampling>, <labeling>, <validation-set>, <validate-llm>, (3.2, 4.73))),
    edge(<reporting>, "-|>"),

    edge(<validation-phase.north>, <start>, "-|>", bend: -10deg, stroke: colors.at(1).darken(30%)),

    group(<artifacts>, [Artifacts], color: colors.at(3), transparentize: 60%, enclose: (<query-string>, <tool-relations>)),
    edge(<artifacts>, <reporting>, "-|>", stroke: colors.at(3).darken(20%)),
    manual_procedure(<reporting>, (2,6))[Reporting],

    edge("-|>"),
    end(<end>, (1,6)),
  ))
}
