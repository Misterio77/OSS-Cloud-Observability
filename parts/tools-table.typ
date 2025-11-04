#import "data.typ"
#import "colors.typ"


#figure(caption: [Selected tools], table(columns: 3,
  [*Tool*], [*Studies*], [*Roles*],
  ..data.tools_selected
    .sorted(key: it => -it.sources.len())
    .map(((name,sources,roles)) => (
      name, str(sources.len()), roles.join(", ")
    )).flatten(),
)) <tools-table>
