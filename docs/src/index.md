# PowerAnalytics.jl

## Overview

PowerAnalytics.jl is a Julia package designed to support power system simulation results analysis. It relies on results generated from [`PowerSimulations.jl`](https://github.com/NREL-Sienna/PowerSimulations.jl) and data structures defined in [`PowerSystems.jl`](https://github.com/NREL-Sienna/PowerSystems.jl). PowerAnalytics also provides the data collection, aggregation, and subsetting for [`PowerGraphics.jl`](https://github.com/NREL-Sienna/PowerGraphics.jl).

The tutorial, how-to, and explanation sections of the documentation are still under construction; the most informative section is the [public API reference](reference/public.md). PowerAnalytics depends heavily on the `ComponentSelector` feature of PowerSystems, documented [here](https://nrel-sienna.github.io/PowerSystems.jl/stable/api/public/#PowerSystems.get_groups-Tuple{ComponentSelector,%20System}).

## Installation

The latest stable release of PowerAnalytics can be installed using the Julia package manager with

```julia
] add PowerAnalytics
```
