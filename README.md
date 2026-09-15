# StatusHomeBarAdjuster 1.2.0

RootHide / arm64e / iOS 16.x.

## Geometry

Status Bar and Home Bar use a height value from 0 to 120 px.

- 0 px: UI region collapses to its edge.
- 30 px: reference/default height.
- 60/90/120 px: region grows by that height.
- Status Bar: top is the screen edge; its bottom edge moves with the selected height.
- Home Bar: bottom is the physical screen edge; its top edge moves with the selected height.
- Landscape is untouched.
- No icon/pill scaling.
- Home gesture recognizers are not modified.
