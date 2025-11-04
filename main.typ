#import "parts/data.typ"

#let title = [Open Source Software Ecosystem for Cloud Observability: \ 
An Overview and Trends]

#let authors = (
  (
    name: [Gabriel Silva Fontes],
    email: "g.fontes@usp.br",
    institute: "University of São Paulo",
    city: "São Carlos, Brazil",
  ),
  (
    name: [ Vasilios Andrikopoulos],
    email: "v.andrikopoulos@rug.nl",
    institute: "University of Groningen",
    city: "Groningen, The Netherlands",
  ),
  (
    name: [Elisa Yumi Nakagawa],
    email: "elisa@icmc.usp.br",
    institute: "University of São Paulo",
    city: "São Carlos, Brazil",
  ),
)

#let conference = (
  name: [14th IEEE/ACM International Workshop on Software Engineering for Systems-of-Systems and Software Ecosystems],
  short: [SESoS 2026],
  date: [April 12],
  year: [2026],
  venue: [Rio de Janeiro, Brazil],
)

#import "parts/layout.typ": acmart, acmart-ref, acmart-keywords
#show: acmart.with(
  title: title,
  authors: authors,
  conference: conference,
  copyright: none,
)

= Abstract

*Context*:
With the adoption of cloud computing and the evolution of IT and software engineering practices, observability, the ability to systematically measure and monitor software systems, becomes a growing concern. Cloud computing is very heterogeneous, and thus creating, maintaining, and observing systems built on it requires integration of multiple tools. Open source software (OSS) tooling emerged as a de-facto standard in multiple areas, including cloud observability. The ecosystem formed by OSS observability tooling is large and often difficult to navigate. 
*Objective*:
The main goal of this paper is to present the OSS Ecosystem formed by cloud computing observability tooling, by providing an overview of the main tools and identifying trends on their integration.
*Method*:
We searched the literature for studies on cloud observability and used an automated named-entity recognition (NER) method to extract candidate observability tools from abstracts. We selected the OSS observability tools according to well-defined criteria. Following this, we used keyword matching on the tools' source codes, revealing integration code, documentation, and other types of relations.
*Results*:
As a result, we found #data.tools_selected.len() OSS observability tools and derived quantitative measures on their relations to one another. The tools serve different roles in observability stacks, with our results serving as a proxy measure on how strongly they relate to one another.
*Conclusion*:
We present an overview of different tools, how frequently they appear, their functionality, and a visualization of their relations. Some trends are identified, such as the centrality of some tools (e.g. _Prometheus_), common stacks (e.g. _ELK_, _TICK_), and outliers (_Thingspeak_). We discuss topics such as measuring relations, standardization, proprietary lock-in, among others.

#acmart-keywords(("Open Source Software", "Cloud", "Observability", "Mining Software Repository"))
#acmart-ref(title, authors, conference, "https://doi.org/XXXX")

= Introduction <introduction>

Catalyzed by the revolution brought by the public cloud and the advance of modern IT practices, such as the Site Reliability Engineering concept @beyer2016site and the DevOps movement, systems administration is shifting from operational into an engineering domain @beyer2016site. With this shift, a need to systematically measure and monitor software systems emerge that is known as _observability_. Observability is a concept originating from control theory, meant to measure the degree to which a system's internal state can be inferred from its output at any point in time @niedermaier2019observability. Cloud observability, in turn, is the degree to which (cloud) infrastructure, applications deployed on this infrastructure, and their interactions can be monitored using data such as logs, metrics, and traces @picoreti2018multilevel.

The cloud computing ecosystem is, by its very nature, a heterogeneous combination of different platforms, software, and systems. Ranging from on-premises infrastructure and traditional workloads, to a multitude of different cloud providers and cloud-native container orchestration, plus dozens of different configuration management tools (with varying degrees of compatibility), the list goes on and on. In this scenario, it is challenging to create, maintain, and observe systems that rely on such a diverse ecosystem. This diversity makes the interoperability requirement critical @6133225@6480040. Open Source Software (OSS) is a natural fit for this, due its effect on standardization and commodification @Linden2009. There are many cases where an OSS' potential for interoperability helped it become a dominant force in software engineering tooling, including Docker/OCI, Kubernetes, Linux, Git, LSP, among others. Cloud observability is no different, as we will discuss further in this work.

Just as the cloud systems that it aims to observe, the OSS ecosystem for cloud observability is similarly diverse and heterogeneous. This ecosystem includes tools for tracing, benchmarking, logging, aggregation, storage, visualizations, alerting @beyer2016site, with many different tools used in different contexts and business domains. Understanding this ecosystem becomes crucial for both researchers in the cloud computing domain, as well as practitioners looking to build more reliable and observable cloud-based systems. This understanding, however, is not just about which tools there are out there, but how they integrate and which role they play in an observability stack.

While there is some non-academic effort to better understand subsets of this ecosystem @cnf-landscape, current literature lacks a wider study on the OSS ecosystem for cloud observability. With that in mind, the main goal of this paper is to present an overall view of the OSS tooling ecosystem used for cloud observability. To achieve our goal and identify trends in this field, we defined two research questions (RQs):

- *RQ1*: What are the most relevant OSS tools in cloud observability stacks?; and
- *RQ2*: How are OSS tools combined to form cloud observability stacks?

Following this, we scrutinized the scientific literature and located #data.scopus_results.len() studies, from which we identified a total of #data.tools_selected.len() tools extracted from #data.papers_selected.len() final studies. As a main result, we observed the centrality of some tools, and tools that cluster together. We intend that the overview presented in this paper can bring implications for both practitioners and researchers.

The remainder of this paper is structured as follows: Section @research-method outlines the research method; Section @results reports the main results; Section @discussion presents our main findings, threats to validity, and future work; Section @conclusions concludes our work.

= Research Method <research-method>

#include "parts/fig-research-method.typ"

@fig-research-method provides an overview of the research method and the reproduction package files that correspond to each step. The reproduction package is made available#footnote[https://github.com/Misterio77/OSS-Cloud-Observability] to replicate the entirety of this research.


== Search query

To build our initial set of tools, we extracted them from a large population of research studies. For that, we searched Scopus #footnote[https://scopus.com] with the following query:

#raw(block: false, lang: "sql", data.scopus_search_query)

Our goal includes, but is not limited to finding more niche tools, and thus it benefits from a large and diverse sample size. To avoid missing relevant tools, this search query intentionally did not try to exclude research software nor proprietary software, thus leaving this filtering for manual selection, as described in Section @tool-selection.

The search resulted in a set of *#data.scopus_results.len()* studies, which were exported into a CSV in the following format: ```csv "Title","Year","DOI","Link","Abstract" ```. This data is available in the reproduction package as #raw(data.reprod_files.scopus_search_results.file).


== Tool extraction from abstracts <tool-extraction>
 
This is a problem in the class of Named-entity Recognition (NER) @pakhale2023ner, albeit a single-class one. As the intent is to extract tool names from the studies, a method that can be aware of context, such as BERT or an LLM, is ideal. For this extraction, due to ease of access and previous experience, we decided to use an LLM to extract the tools from abstracts.
 
The reason for using the abstracts alone, besides ease of automation and availability, is that an abstract can fit together with the LLM's prompt in most models' context windows, drastically reducing hallucinations and costs when compared to the full texts. The main risk from this strategy is missing tools that only appear in the full text; hence, we mitigated it in two ways: (i) by using a large amount of studies; and (ii) by calibrating the prompt using a validation set, as discussed next.

=== Validation set <validation-set>

#let predefined_keywords = ("grafana", "prometheus", "graphite", "opentelemetry", "elasticsearch", "fluentd", "kibana", "logstash", "jaeger", "influxdb", "ceilometer")
#let validation_set = data.validation_set_results
#let from_keyword = validation_set.filter(((source,)) => source == "keyword")
#let from_random = validation_set.filter(((source,)) => source == "random")

A validation set of *#validation_set.len()* manually extracted abstracts was created. This set was used to estimate precision and recall of the overall dataset and to calibrate the LLM prompt used for extraction. The first attempt was by randomly sampling abstracts. After analysis, it was evident that the negatives (i.e., abstracts not containing any observability tool names) made up around 80-90% of the corpus, making the data very sparse. To get a set with a higher share of positives, we decided to use a combination of keyword spotting (by matching the text with a few known observability tools#footnote(predefined_keywords.join(", "))) and random sampling. The set is composed of *#from_keyword.len()* studies originating from keyword match and *#from_random.len()* from random sampling. The script that reproduces this step is available in the reproduction package as #raw(data.reprod_files.validation_set_script.file). The authors then manually extracted tools from these abstracts, inserting the annotations into the dataset, which is available in the reproduction package as #raw(data.reprod_files.validation_set_results.file).

=== LLM extraction <llm-extraction>

The extraction method consists of feeding each study's abstract to an LLM (in this case, DeepSeek-V3 #cite(<deepseekv3>)), with the following prompt:

#quote()[
  _You will receive a paper abstract that relates to cloud observability/monitoring/logging/tracing tools. Enumerate all observability/monitoring/logging/tracing tools mentioned in it. Respond with the names separated by comma: `tool1,tool2,tool3`. If there are no relevant tools, reply with an empty string._
]

#let relevant = data.extraction_validation.filter(((relevant,)) => relevant)
#let irrelevant = data.extraction_validation.filter(((relevant,)) => not relevant)
#let retrieved = data.extraction_validation.filter(((retrieved,)) => retrieved)

#let true_positives = relevant.filter(((retrieved,)) => retrieved)
#let false_negatives = relevant.filter(((retrieved,)) => not retrieved)
#let false_positives = irrelevant.filter(((retrieved,)) => retrieved)

#let recall = calc.round(true_positives.len() / relevant.len() * 100)
#let precision = calc.round(true_positives.len() / retrieved.len() * 100)
#let f_measure = 2 * calc.round((precision*recall)/(precision + recall))

We used the validation set to evaluate and calibrate this prompt. By using the LLM to extract tools from that set, we achieved recall *#recall%*, precision *#precision%*, and $F_1$ *#f_measure%* (#true_positives.len() true positives, #false_positives.len() false positives, and only #false_negatives.len() false negatives) on the validation set. The key metric here is the recall, as this LLM extraction is then used for a manual selection, so it is crucial that false negatives are minimized.
#let percent_extracted = calc.round(data.llm_extracted_papers.len() / data.scopus_results.len() * 100)

From the full set, the LLM extracted a total of *#data.llm_extracted_tools.len()* candidate tools, originating from *#data.llm_extracted_papers.len()* studies (*#percent_extracted%* of *#data.scopus_results.len()* total studies).
This step can be fully reproduced via the script #raw(data.reprod_files.llm_extraction_script.file), and its results are available in #raw(data.reprod_files.llm_extraction_results.file). These tools were then manually selected, as detailed in @tool-selection.

== Manual tool selection <tool-selection>

We manually examined the #data.llm_extracted_tools.len() candidate tools and the studies they appeared on and selected the tools according to the following selection criteria:

- Inclusion Criteria (IC):
  - *IC1*: The tool is/was a piece of Free/Open Source Software, meaning licensed under one of the OSI#footnote[https://opensource.org/licenses]'s or FSF#footnote[https://gnu.org/licenses/license-list.html]'s approved software licenses; and
  - *IC2*: The tool is used/discussed as part of a cloud observability solution. 
- Exclusion Criterion (EC):
  - *EC1*: The tool is a piece of research software and not otherwise available as an actual FOSS project on the web or mentioned anywhere else on the web besides the studies that introduce it.

Besides the tool name and studies it originates from, we also annotated each tool with:

1. A list of its relevant software repositories (e.g., Git, SVN), located via web searches.
2. Its main functions/roles, also located via web searches, and organized roughly based on @kosinska2023observability:
  1. `instrumentation` (Instrumentation): allows systems to export observability data (e.g. libraries, exporters).
  2. `collection`/`processing` (Data Collector): aggregates, processes, and collects data.
  3. `storage` (Data Backends): long-term storage, querying.
  4. `visualization`/`alerting`/`analysis` (Analysis/Visualization): understanding of the system, root cause analysis, discovering "unknowns".

This data is available in the reproduction package as #raw(data.reprod_files.tool_selection_manual.file).

== Tool relations <tool-relations>

To find the relations between OSS tools, we downloaded their source code, and, for each tool, programmatically matched occurrences of every other tools' names. This step can be reproduced using #raw(data.reprod_files.tool_code_ocurrences_script.file) and its results are available as #raw(data.reprod_files.tool_code_ocurrences_result.file). The number of occurrences thus represent how much a tool "cares" about other tools. A deeper study on the nature of each relation is out of scope for this study, but we briefly discuss this in @future-work.

= Results <results>

This section focuses on answering the two RQs defined in Section @introduction.

== OSS tools in Cloud Observability Stacks

#let percent_selected = calc.round(data.papers_selected.len() / data.scopus_results.len() * 100)

We selected *#data.tools_selected.len()* tools, originating from *#data.papers_selected.len()* studies (*#percent_selected%* of *#data.scopus_results.len()* total studies). @tools-table, in the Appendix, contains the full set of selected tools, the amount of studies from which they were extracted, and our annotations on the main functions each of them provide in an observability stack. As it can be seen from the table, there is a long list of tools with singular presence in studies, while a few tools like _Thingspeak_ and _Prometheus_ dominate the discourse.

#include "parts/fig-tool-occurrence.typ"

@fig-tool-occurrence visualizes how frequently each tool appears, in number of studies. Notoriously, _Prometheus_ and _Grafana_ are very frequently mentioned in the studies, which correspond to our expectations and industry experience, where the two are frequently combined for a basic metric+visualization stack. _Thingspeak_ being highly mentioned, while unexpected, is possibly an indicator that IoT research frequently intersects with cloud computing.

#include "parts/fig-tool-role.typ"

@fig-tool-role shows how frequent each role (as defined in @tool-selection) is. Some tools have multiple roles (e.g. _Grafana_ has both `visualization` and `alerting`). We can see a very high frequency in the collection role; besides dedicated collectors, most instrumentation and processing tools seem to have some sort of collection/aggregation mechanism built-in.

#include "parts/fig-yearly-distribution.typ"

@fig-yearly-distribution shows the yearly distribution of studies with at least one selected tool. We can see that there is a growing trend, possibly indicating the increased interest in the area. Our data contains studies from up until October 2025, thus 2024 studies are slightly more present than 2025 in the graph.

#block(above: 0.8em, stroke:luma(10), inset: 0.5em)[
  Answering RQ1: _Prometheus_ is ubiquitous in the cloud observability ecosystem. _Nagios_, _Grafana_ and _ElasticSearch_ are also frequent appearances. _Thingspeak_ is an interesting outlier, representing the IoT sub-ecosystem. Collection functionality is the most frequent, followed by instrumentation and visualization.
]

#figure(caption: [Relations between tools, clustered and weighted by relative code occurrence], placement: auto, scope: "parent", data.clustering_results) <fig-relations>

== Combinations of OSS Tools in Cloud Observability Stacks <combination-of-oss-tools>

To better visualize the relation data, we conducted a network analysis in it, with the results shown in @fig-relations. For this figure, we represent each tool as a node. The relation between tools, from @tool-relations, is represented as graph edges, whose weight is a normalized form of the number of occurrences the destination node's name has in the origin node's codebase (i.e. how much a tool "cares" about the other tool, relative to all other tools it cares about). The node size is derived from the sum of the weights of connections pointing at that node, interpreted as the tool's "connectedness" (i.e. centrality in the ecosystem). Each node's color is a visualization of community clustering, that groups tightly connected nodes together. Edges whose weights were lower than 0.05 (i.e. 5% of all keyword matches that codebase has) were hidden from the visualization, for improved visibility.

We can easily see in the figure how many tools relate to _Prometheus_; due to its format being the dominant one for metrics, most other tools export metrics that are compatible with _Prometheus_.  _Thingspeak_ is very disconnected from the other tools, which hints that IoT tooling tends to be more standalone. _JoularJX_ and _Powerjoular_, a pair of tools built together to, respectively, collect and aggregate power consumption data, also appear isolated yet tightly coupled together. Some ecosystems can be clearly seen being formed in the figure: the _ElasticSearch_+_Logstash_+_Kibana_ ELK stack, and the _Telegraf_+_InfluxDB_+_Chronograf_+_Kapacitor_ TICK stack being some obvious ones. The directionality of the relations is also representative of how the tools behave, with _Grafana_ heavily relating to _Prometheus_ (it has a _Prometheus_ datasource built-in @grafana-prometheus-docs), but not the other way around (i.e.  _Prometheus_ knows almost nothing about _Grafana_).

#block(above: 0.8em, stroke:luma(10), inset: 0.5em)[
  Answering RQ2: some common stacks appear in this research, such as ELK and TICK. Some tools are highly integrated in the ecosystem, with _Prometheus_ being a central piece. _Thingspeak_ is an outlier and shows that IoT tends toward standalone solutions.
]

= Discussion <discussion>

This section discusses our main findings, the threats to the validity of this study, and future work.


== Main Findings

The main findings resulting from our investigation of OSS tools for cloud observability are:

- *Quantitative code matching can be a good proxy to find relations between codebases*. Our approach of matching the names of each tool on other tools' codebases worked. @fig-relations clearly shows clustering between well-known combinations: ElasticSearch+Logstash+Kibana (ELK stack), _Telegraf_+_InfluxDB_+_Chronograf_+_Kapacitor_ (TICK stack). We can also see library usage (e.g., _OpenTelemetry_), the most ubiquitous tools (_Prometheus_) being highly referenced to, as well as some disconnected clusters (e.g., _Powerjoular_+_JoularJX_, _Thingspeak_). Notably, our approach is very accurate in modeling directed relations, such as _Grafana_ integrating with _Prometheus_ @grafana-prometheus-docs, but not the other way around. Finally, our approach is heavily automated, and thus scales much better than the alternatives that involve manual labeling or more qualitative analysis. It should be interesting to apply these techniques to different Software Ecosystems.

- *OSS ecosystems can challenge proprietary lock-in*. Our data extraction step yielded some proprietary software (e.g. _CloudWatch_, _AzureWatch_), many of them usually specific to a single cloud. OSS tools appeared in abstracts together with proprietary tools from different clouds, hinting that these integrations happen even across proprietary ecosystems from public clouds. Practitioners should consider interoperability when adopting observability tooling, specially in multi-cloud scenarios.

- *Some tools are de-facto standards, bringing standardization but risking over-reliance*. It is interesting to see how Prometheus has become so ubiquitous that there are references to it in the code of basically every single cloud observability tool that exists. If a software exports metrics, it is probably in the Prometheus exposition format. Although _Prometheus_'s community-based governance brings some safety, over-reliance on a single implementation can be problematic, thus bringing the need of standardization. _OpenTelemetry_ has recently emerged as a more standardized framework for different aspects of observability (including compatibility with the _Prometheus_ exposition format) @prometheusotel, and it is interesting to adoption grow. The connection graph we built can be a helpful metric to determine which OSS tools are becoming critical, thus should be prioritized for standardization and/or alternative implementations by OSS communities and funding agencies.

- *The line between an _observability tool_ and a tool that _can be used for observability_ can be thin*. During our manual selection step, some tools were difficult to classify. For example, _Kafka_ is not necessarily built for observability solutions, but its usage is so frequent that it becomes clear that it should be labeled as such. But what about other message queues? Or storage systems? Some more research is required to effectively draw this line.

== Threats to Validity

As with any secondary studies, threats to validity must be considered as well as mitigation actions, as discussed below:

- *Not all tools are mentioned in scientific literature*. There are a few tools the authors know about from their exposure to cloud observability solutions that did not appear in any of the abstracts our search yielded. This includes _Mimir_, _Loki_, _Graphite_, and _Thanos_. This means that including other datasources and analysis techniques could provide a more complete set of tools. This is an acknowledged limitation in our study.


- *Sparsity of dataset*. The abstract dataset is very sparse, making validation harder. Only *#percent_selected%* of the total corpus includes at least one tool from the final selection. We mitigated this by building a validation set that included both known tools as well as randomly sampled studies.

- *LLM bias*. Although we calibrated the prompt to minimize false negatives, the LLM can be biased towards more well-known tools. We mitigated this by inspecting the abstracts of extracted studies (#data.llm_extracted_papers.len()), this same inspection is, however, not possible in the negative population, as it is very large. The mitigation provided by the validation set (@validation-set), with a high recall value, is considered sufficient.

- *Abstracts may not contain every tool relevant to the work*. Using only the abstracts (as opposed to the fulltexts) can leave out relevant tools. This is somewhat mitigated by the large corpus of studies we used, and is a tradeoff we accepted to build a more automated research method.

- *Code matches can contain false positives*. Some codebases, such as ElasticSearch's, contain files such as wordlists. This is mitigated by making the weights relative and discarding less relevant edges. Future research could involve additional heuristics.

- *Code matches can contain transitive relations*. Transitive dependencies/integrations are also frequently matched, which might be an issue if the intention is to only model direct ones. This can be partially mitigated by excluding lockfiles. We decided to not qualitatively differentiate the nature of each relation, so this is considered out of scope for this paper.

- *Human error during selection*. As with any classification based on human decisions, our selection process could contain errors or be biased. This was mitigated by consensus between the authors and by carefully researching each candidate tool.

== Future Work <future-work>

Based on the results of our investigation, we can suggest the following future work:

- *A qualitative study of tool relations*. The relations we found include: code integrations (e.g., _Grafana_ having a _Prometheus_ data source), deployment code, examples where they are used together, and documentation comparing the two. Looking further into their nature could be an interesting direction.

- *Other datasources besides academic studies*. Although useful for casting a wide net, academic studies might not be enough to locate all tooling, specially emerging ones. Other methods such a multivocal literature reviews to find the set of tools might be interesting to explore.

- *Applying our method to other ecosystems*. The code keyword matching approach is simple, very scalable, and seems to provide good results. One could apply this technique to other ecosystems.

- *A better definition of observability tooling is needed*. Some tools are used in observability but do not define themselves as observability tools. Some better heuristic to make this classification could be explored.

- *Other heuristics for finding relations*. Research on more heuristics for the relations can be interesting. For example, by analyzing the common contributors between two projects, one could measure integration and/or cross-pollination between different software projects.

- *Compare with qualitative analysis*. By comparing a more qualitative analysis of the relations, one could formally prove how correct our automated quantitative analysis is.

= Conclusions <conclusions>

As IT operations shift into an Engineering activity, Observability also grows as an important topic for SE research. In our work, our objective was to provide an accurate starting point to researchers exploring the OSS Observability ecosystem. Our research shows a selection of #data.tools_selected.len() OSS tools, a categorization on their functionality, and a quantitative measure of the relations between one other. A few tools are shown to have a central role in the ecosystem, such as _Prometheus_, others appear clustered in stacks, such as _ELK_ (_ElasticSearch_, _Logstash_, _Kibana_) and TICK (_Telegraf_), _InfluxDB_, _Chronograf_, _Kapacitor_). We also showcase some outliers, such as _Thingspeak_ which does not relate to any other tool we have researched, as well as tools that appear isolated as a pair, such as _JoularJX_ and _PowerJoular_.

Our methodology is very automated and can be helpful for any exploratory study of a Software Ecosystem where source code is available for analysis. This sort of overview can be helpful for practitioners to locate additional components their observability stack might be missing, as well as to discover alternatives for tools they are using.

= Acknowledgments
This study was financed by São Paulo Research Foundation (FAPESP) (2023/00488-5) and National Council for Scientific and Technological (CNPq) (313245/2021-5). This work was also supported by ITEA4 and RVO under grant agreement No.~22035 MAST (https://itea4.org/project/mast.html).

#bibliography(title: "References", "references.bib", full: true)

#set heading(numbering: "A.1", supplement: [Appendix])
#counter(heading).update(0)
#colbreak(weak: true)

= Selected Tools

#include "parts/tools-table.typ"
