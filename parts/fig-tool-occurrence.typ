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
  import "@preview/cetz:0.3.4": canvas, draw, palette
  import "@preview/cetz-plot:0.1.1": chart

  // Get tools, sort by number of appearances
  let data =  data.tools_selected
    .map(((name, sources)) => ((name, sources.len())))
    .filter(((name, count)) => count > 1)
    .sorted(key: it => it.at(1))
    .rev()
  let width = 5.8
  let height = 8.2
  let x-max = 25

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
      draw.content((count*width/x-max + 0.23, idx * (height/data.len() - 0.017) + 0.36), [#count])
    }
  })
}
