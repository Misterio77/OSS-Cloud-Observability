# Latex version

This is the camera ready version for submission at ACM.

The starting point is using typst->html->latex conversion, like so:

```
typst compile main.typ main.html
pandoc main.html --biblatex --shift-heading-level-by=-1 --lua-filter=pandoc-filter.lua --extract-media -o main.tex
```

Then generate each figure as PDF using typst manually (with `set page(width: auto, height: auto, margin: 0)`)

Followed by a lot of manual fixing.
