#import "data.typ"
#import "colors.typ"


#table(columns: 3,
  [*Tool*], [*Studies*], [*Roles*],
  ..data.tools_selected
    .sorted(key: it => -it.sources.dedup().len())
    .map(((name,sources,roles)) => (
      name, str(sources.dedup().len()), roles.join(", ")
    )).flatten(),
)
