# PowerAnalytics.jl

[![main - CI](https://github.com/NREL-Sienna/PowerAnalytics.jl/actions/workflows/main-tests.yml/badge.svg)](https://github.com/NREL-Sienna/PowerAnalytics.jl/actions/workflows/main-tests.yml)
[![codecov](https://codecov.io/gh/NREL-Sienna/PowerAnalytics.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/NREL-Sienna/PowerAnalytics.jl)
[![Documentation Build](https://github.com/NREL-Sienna/PowerAnalytics.jl/workflows/Documentation/badge.svg?)](https://nrel-sienna.github.io/PowerAnalytics.jl/stable)
[<img src="https://img.shields.io/badge/slack-@Sienna/PG-sienna.svg?logo=slack">](https://join.slack.com/t/nrel-sienna/shared_invite/zt-glam9vdu-o8A9TwZTZqqNTKHa7q3BpQ)
[![PowerAnalytics Downloads](https://shields.io/endpoint?url=https://pkgs.genieframework.com/api/v1/badge/PowerAnalytics)](https://pkgs.genieframework.com?packages=PowerAnalytics)

PowerAnalytics.jl is a Julia package that contains analytic routines for power system simulation results in the Sienna ecosystem, specifically from [PowerSimulations.jl](https://github.com/NREL-Sienna/PowerSimulations.jl).

## Installation

```julia
julia> ]
pkg> add PowerAnalytics
```

## Usage

`PowerAnalytics.jl` uses [PowerSystems.jl](https://github.com/NREL/PowerSystems.jl) and [PowerSimulations.jl](https://github.com/NREL/PowerSimulations.jl) to handle the data and execution power system simulations.

```julia
using PowerAnalytics
# where "res" is a PowerSimulations.SimulationResults object
gen = get_generation_data(res)
```

## Development

Contributions to the development and enhancement of PowerAnalytics is welcome. Please see [CONTRIBUTING.md](https://github.com/NREL-Sienna/PowerAnalytics.jl/blob/main/CONTRIBUTING.md) for code contribution guidelines.

## License

PowerAnalytics is released under a BSD [license](https://github.com/nrel-sienna/PowerAnalytics.jl/blob/main/LICENSE). PowerAnalytics has been developed as part of the Scalable Integrated Infrastructure Planning (SIIP)
initiative at the U.S. Department of Energy's National Renewable Energy Laboratory ([NREL](https://www.nrel.gov/))
