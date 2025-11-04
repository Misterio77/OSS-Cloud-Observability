#import "data.typ"
#import "colors.typ": colors

#figure(caption:
[Number of tools per role \ (Some tools have multiple)], 
{
  import "@preview/cetz:0.3.4": canvas, draw, palette
  import "@preview/cetz-plot:0.1.1": chart

  let roles = data.tools_selected
    .map(it => it.roles)
    .flatten()
    .dedup()
  let data = roles
    .map((role) => (
      role, data.tools_selected.filter(it =>
        it.roles.contains(role)
      ).len()
    ))
    .sorted(key: it => it.at(1))
    .rev()
  let width = 6
  let height = 3
  let x-max = 36

  canvas({
    chart.barchart(
      size: (width, height),
      bar-style: palette.new(colors: colors),
      axis-style: "scientific",
      x-tick-step: 5,
      x-max: x-max,
      data
    )
    // Add data labels
    for c in data.rev().enumerate() {
      let (idx, (_, count)) = c
      draw.content((count*width/x-max + 0.24, idx * (height/data.len() - 0.055) + 0.38), [#count])
    }
  })
}) <fig-tool-role>
