# PowerAnalytics.jl

## Overview

PowerAnalytics.jl is a Julia package designed to support power system simulation results analysis. It relies on results generated from [`PowerSimulations.jl`](https://nrel-sienna.github.io/PowerSimulations.jl/stable/) and data structures defined in [`PowerSystems.jl`](https://nrel-sienna.github.io/PowerSystems.jl/stable/). PowerAnalytics also provides the data collection, aggregation, and subsetting for [`PowerGraphics.jl`](https://nrel-sienna.github.io/PowerGraphics.jl/stable/).

The tutorial, how-to, and explanation sections of the documentation are still under construction; the most informative section is the [public API reference](reference/public.md). PowerAnalytics depends heavily on the `ComponentSelector` feature of PowerSystems.jl, documented [here](https://nrel-sienna.github.io/PowerSystems.jl/stable/api/public/#InfrastructureSystems.ComponentSelector).

## Installation

The latest stable release of PowerAnalytics can be installed using the Julia package manager with

```julia
] add PowerAnalytics
```

!!! note
    
    The latest stable release of `PowerAnalytics.jl` supports the `PowerSystems.jl` 5.0
    ecosystem, except that all results processing is done in wide format rather than long
    format, which precludes support for greater than two dimensional results. For now,
    greater than two dimensional results must be processed manually; we are working to add
    support for these in a future release.

## About Sienna

`PowerAnalytics.jl` is part of the National Renewable Energy Laboratory's
[Sienna ecosystem](https://nrel-sienna.github.io/Sienna/), an open source framework for
power system modeling, simulation, and optimization. The Sienna ecosystem can be
[found on GitHub](https://github.com/NREL-Sienna/Sienna). It contains three applications:

  - [Sienna\Data](https://nrel-sienna.github.io/Sienna/pages/applications/sienna_data.html) enables
    efficient data input, analysis, and transformation
  - [Sienna\Ops](https://nrel-sienna.github.io/Sienna/pages/applications/sienna_ops.html) enables
    enables system scheduling simulations by formulating and solving optimization problems
  - [Sienna\Dyn](https://nrel-sienna.github.io/Sienna/pages/applications/sienna_dyn.html) enables
    system transient analysis including small signal stability and full system dynamic
    simulations

Each application uses multiple packages written in the [`Julia`](http://www.julialang.org)
programming language.
