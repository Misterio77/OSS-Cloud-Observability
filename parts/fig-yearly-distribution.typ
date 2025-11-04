#import "data.typ"
#import "colors.typ": colors

#figure(caption: [Yearly study distribution], {
  import "@preview/cetz:0.3.4": canvas, draw, palette
  import "@preview/cetz-plot:0.1.1": chart

  let data = range(2010, 2026).map((x) => (x, data.papers_selected.filter(((Year,)) => Year == str(x)).len()))
  let width = 7.6
  let height = 4.1
  let y-max = 25

  canvas({
    draw.set-style(axes: (bottom: (tick: (label: (angle: 60deg, anchor: "east")))))
    chart.columnchart(
      size: (width, height),
      bar-style: palette.new(colors: colors),
      axis-style: "scientific",
      y-tick-step: 5,
      y-max: y-max,
      data
    )
    // Add data labels
    for c in data.enumerate() {
      let (idx, (_, count)) = c
      draw.content((idx * (width/data.len() - 0.025) + 0.4, count*height/y-max + 0.2), [#count])
    }
  })
}) <fig-yearly-distribution>

