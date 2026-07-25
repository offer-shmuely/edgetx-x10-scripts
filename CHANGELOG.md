# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## next
-
-


### LogViewer2

## [2.7] - 2026-07
### Changed
- allow min/max in visble area (instead of whole graph)
- estimate the value between two points (linear interpolation) in high zoom, to how more accurate values on steep grapg
- voltage (RxBat/TxBat/Vbat/Vbec/Vcel) are now presented with 2 digit after the period
- support bigger log files
- add more zoom levels (20x, 30x)

### Fixed
- fix: low level stick sliding cause graph to jump instead of move
-


## [2.6] - 2026-07
### Changed
- allow using aileron stick to scroll graph in addition  to touch
- allow using rudder stick to zoom the graph in addition  to touch
- show popup message during the long zooming interval
- validate the zoom on the cursor line
### Fixed
- fix crash when no log files exist
- improve files selection handling when no valid log exists



---


