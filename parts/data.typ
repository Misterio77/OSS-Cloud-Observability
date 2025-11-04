// This file contains data loading and processing that is used through the paper (i.e. for building table, showing numbers, etc)
// We load data from our `reprod` files, which makes the paper dynamic to any future changes

// List of files that were used/produced for the paper
#let reprod_files = (
  scopus_search_query: (id: "00", ext: "txt", file: "00-scopus-search-query.txt"),
  scopus_search_results: (id: "01", ext: "csv", file: "01-scopus-search-results.csv"),
  validation_set_script: (id: "02", ext: "py", file: "02-validation-set-script.py"),
  validation_set_results: (id: "03", ext: "json", file: "03-validation-set-results.json"),
  llm_extraction_script: (id: "04", ext: "py", file: "04-llm-extraction-script.py"),
  llm_extraction_results: (id: "05", ext: "json", file: "05-llm-extraction-results.json"),
  tool_selection_manual: (id: "06", ext: "yaml", file: "06-tool-selection-manual.yaml"),
  tool_code_ocurrences_script: (id: "07", ext: "py", file: "07-tool-code-occurrences-script.py"),
  tool_code_ocurrences_result: (id: "08", ext: "json", file: "08-tool-code-occurrences-results.json"),
  tool_clustering_script: (id: "09", ext: "py", file: "09-tool-clustering-script.py"),
  tool_clustering_results: (id: "10", ext: "svg", file: "10-tool-clustering-results.svg"),
  tool_integration_manual: (id: "11", ext: "yml", file: "11-tool-integration-manual.yml"),
)

#let reprod_dir = "../reprod/"

// Load data files (json, csv, yaml, image, etc)
#let scopus_search_query = read(reprod_dir + reprod_files.scopus_search_query.file)
#let scopus_results = csv(reprod_dir + reprod_files.scopus_search_results.file, row-type: dictionary)
#let validation_set_results = json(reprod_dir + reprod_files.validation_set_results.file)
#let llm_extraction_results = json(reprod_dir + reprod_files.llm_extraction_results.file)
#let tools_selected = yaml(reprod_dir + reprod_files.tool_selection_manual.file)
#let clustering_results = image(reprod_dir + reprod_files.tool_clustering_results.file)

// Unique tools extracted in validation set
#let validation_set_tools = validation_set_results.map(it => it.tools).flatten().dedup()
// Papers from validation set which wielded at least one tool
#let validation_set_extracted_papers = validation_set_results.filter(it => it.tools != ())

// Papers which LLM extraction wielded at least one tool
#let llm_extracted_papers = llm_extraction_results.filter(it => it.tools != ())
// Deduplicated list of tools extracted by LLM
#let llm_extracted_tools = llm_extraction_results.map(it => it.tools).flatten().dedup()

// Filtered version with only the papers from validation set
#let llm_extraction_validation = llm_extraction_results.filter(((id,)) => id in validation_set_results.map(((id,)) => id)) 

// An array whose values contain (id, tool, relevant, retrieved)
#let extraction_validation = {
  let tools = (validation_set_results + llm_extraction_validation).map(((tools,)) => tools).flatten().dedup()

  let r = ()
  for (id,) in validation_set_results {
    for tool in tools {
      r.push((
        id: id,
        tool: tool,
        relevant: tool in validation_set_results.filter(it => it.id == id).map(((tools,)) => tools).flatten(),
        retrieved: tool in llm_extraction_results.filter(it => it.id == id).map(((tools,)) => tools).flatten(),
      ))
    }
  }
  r
}

// Papers that contain a tool from my final manual selection
#let papers_selected = tools_selected.map(it => it.sources).flatten().dedup().map(it => scopus_results.at(it))
