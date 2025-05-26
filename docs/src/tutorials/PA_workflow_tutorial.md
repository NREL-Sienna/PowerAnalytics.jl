# [Simulation Scenarios Analysis](@id Scenarios_PA_tutorial)

## System

In this tutorial, we postprocess the simulation results of the Reliability Test System Grid Modernization Lab Consortium ([RTS-GMLC](https://github.com/GridMod/RTS-GMLC)) system ([DOI: 10.1109/TPWRS.2019.2925557](https://doi.org/10.1109/TPWRS.2019.2925557)), which is an updated version of the [RTS-96](https://ieeexplore.ieee.org/document/780914?arnumber=780914&tag=1) with an artificial location situated on an area that covers parts of California, Nevada and Arizona in the southwestern United States. 

The RTS-GMLC test system consists of: 
- 73 buses, 
- 105 transmission lines, 
- 157 generators (including 57 solar PV facilities, 4 wind turbines, 20 hydro units and 1 concentrated solar plant), 
- 1 short-duration (3 hours) storage device with 100 % charging and discharging efficiency

```@raw html
<p align="center">
  <img src="../../assets/nodemap_RTSGMLC.png" width="700">
  <br>
  <b>Fig. 1 - <a href="https://github.com/GridMod/RTS-GMLC/blob/master/node_re_basemap.png">RTS-GMLC system</a></b>
</p>
```

## Simulation Scenarios

We have obtained simulation results for the following two simulation scenarios: 

- **Scenario 1** : simulation using the RTS-GMLC test system without any additional modifications (baseline scenario) 

- **Scenario 2** : simulation using the RTS-GMLC test system with increased energy and power capacity of the storage device 

    
The simulations were performed using the [PowerSystems.jl](https://nrel-sienna.github.io/PowerSystems.jl/stable/) and [PowerSimulations.jl](https://nrel-sienna.github.io/PowerSimulations.jl/stable/) packages of Sienna. The [`CopperPlatePowerModel`](@extref) formulation was considered for the [`NetworkModel`](https://docs.juliahub.com/General/PowerSimulations/0.30.1/formulation_library/Network.html#PowerSimulations.NetworkModel), while the formulations chosen for each of the component types we want to include in the simulation are presented in the table below: 

| Component Type        | Formulation                     |
|-----------------------|----------------------------------|
| [`Line`](@extref)                  | [`StaticBranch`](@extref)                     |
| [`TapTransformer`](@extref)                  | [`StaticBranch`](@extref)                     |
| [`ThermalStandard`](@extref)       | [`ThermalBasicUnitCommitment`](@extref)    |
| [`RenewableDispatch`](@extref)     | [`RenewableFullDispatch`](@extref)            |
| [`RenewableNonDispatch`](@extref)  | [`FixedOutput`](@extref)                      |
| [`HydroDispatch`](@extref)             | [`HydroDispatchRunOfRiver`](@extref)                  |
| [`HydroEnergyReservoir`](@extref)             | [`HydroDispatchRunOfRiver`](@extref)                  |
| [`EnergyReservoirStorage`](@extref)             | [`StorageDispatchWithReserves`](https://nrel-sienna.github.io/StorageSystemsSimulations.jl/stable/formulation_library/StorageDispatchWithReserves/)                  |
| [`PowerLoad`](@extref)             | [`StaticPowerLoad`](@extref)                  |

!!! info

    More information regarding the different formulations can be found in the [`PowerSimulations.jl` Formulation Library](https://nrel-sienna.github.io/PowerSimulations.jl/stable/formulation_library/Introduction/).
    
We document the above here for completeness, since those will directly define the structure of the optimization problem and consequently its auxiliary variables, expressions, parameters and variables for which realized result values are available. 

The script that was used to configure and execute the simulation scenarios referenced above can be found [here](https://github.com/NREL-Sienna/PowerAnalytics.jl/blob/al/tutorial/docs/src/tutorials/_run_scenarios_RTS_Tutorial.jl) # TODO: update path


## Loading Simulation Scenario Results
We begin by loading all the necessary Julia packages.

```@repl tutorial
using PowerSystems
using PowerSimulations
using StorageSystemsSimulations
using HydroPowerSimulations
using DataFrames
using Dates
using CSV
using Plots
using PowerAnalytics
const PA = PowerAnalytics
```

To begin our analysis, we first specify the directory where the simulation results are stored. In our case, the results of both simulation scenarios have been saved within the same directory. 

```@repl tutorial
results_dir = "_simulation_results_RTS"
```

Once we have defined the directory containing our simulation results, the next step is to load them into a structured format for our analysis. 

[`create_problem_results_dict`](@ref) facilitates this by constructing a dictionary where each key corresponds to a scenario name.

We also specify `"UC"`, which corresponds to the name we assigned when creating the [`DecisionModel`](@extref) and refers to the results of the unit commitment simulation. The `populate_system=true` argument ensures that the system model is attached to the results.

```@repl tutorial
results_all = create_problem_results_dict(results_dir, "UC"; populate_system=true)
```

## Single Scenario Results

In this section of the tutorial, we focus on the results of a single simulation scenario. Since the `results_all` dictionary contains entries for multiple scenarios, we can extract the results for the first one using: 

```@repl tutorial
results_uc = first(values(results_all))
```

### Obtain the generation time series for each individual thermal component of the system 

Let's start by inspecting the available realized variables in our results: 

```@repl tutorial
keys(read_realized_variables(results_uc))
```

Since we have confirmed that the key `ActivePowerVariable__ThermalStandard` exists in our results, we can now extract the generation time series for all the thermal ([`ThermalStandard`](@extref)) generators in our system. To achieve this, we follow two steps:

1) Create a selector that identifies the component type we are interested in (in this case [`ThermalStandard`](@extref)). 
2) Calculate the active power for the corresponding generators of this type using one of [`PowerAnalytics.jl`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/) defined metrics, namely [`calc_active_power`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#PowerAnalytics.Metrics.calc_active_power), which retrieves the generation time series from the results. 

```@repl tutorial
thermal_standard_selector = make_selector(ThermalStandard)
```

Notice that in the resulting dataframe, each column represents the time series of an individual component. This behavior follows from the default settings of [`make_selector`](@ref), since we have not specified any additional arguments to modify the default grouping.

It is also important to keep in mind that by default, only the available components of the system will be included in the resulting dataframe.

!!! info

    For a complete list of the [`PowerAnalytics.jl`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/) built-in metrics, please refer to: [PowerAnalytics Built-In Metrics](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#Built-in-Metrics). 

### Obtain the thermal generation timeseries grouped by prime_mover

In some cases, it is more insightful to aggregate generation by `prime_mover_type`, in order to better understand the relative contributions of different generation technologies across the system.

To achieve this, we modify our selector using [`rebuild_selector`](@ref), specifying `groupby = get_prime_mover_type`. This restructures the selector so that thermal generators with the same `prime_mover_type` are grouped together.  

```@repl tutorial
thermal_standard_selector_pm = rebuild_selector(thermal_standard_selector, groupby = get_prime_mover_type)
```

Once we have this new selector, we use the same metric defined in the previous subsection to compute the aggregated generation time series for each unique `prime_mover_type`.

```@repl tutorial
PA.calc_active_power(thermal_standard_selector_pm, results_uc)
```

### Identify the day of the week with the highest total thermal generation across the entire system

To identify the day of the week with the highest total thermal generation across the system, we begin by creating a component selector that aggregates all [`ThermalStandard`](@extref) components into a single group. 

This is done by setting `groupby = :all` in [`make_selector`](@ref), which considers all thermal generators as a unified entity and performs the desired spatial aggregation.

```@repl tutorial
thermal_standard_selector_sys = make_selector(ThermalStandard; groupby=:all)
```

We again use the built-in [`calc_active_power`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#PowerAnalytics.Metrics.calc_active_power) metric in order to compute the active power time series for this aggregated group. 

The resulting dataframe contains the single time series representing the total thermal generation across all thermal generators in the system.

```@repl tutorial
sys_active_power = PA.calc_active_power(thermal_standard_selector_sys, results_uc)
```

Since our goal is to compare generation values across the days of the week, we perform a temporal aggregation using [`aggregate_time`](@ref). By passing `groupby_fn = dayofweek` as an argument, we group the data by day of the week (where 1= Monday, 2 = Tuesday, etc.), summing the total MWh generated on each weekday across the dataset.

```@repl tutorial
df_day = aggregate_time(sys_active_power; groupby_fn = dayofweek, groupby_col = "agg_day")
```

Finally, we sort the daily values in descending order and create a bar plot using the [`Plots.jl`](https://docs.juliaplots.org/stable/) package to visually compare total thermal generation across days.

```@repl tutorial
using Plots
gr()

df_sorted = sort(df_day, :ThermalStandard, rev=true)

bar(
    string.(df_sorted.agg_day), 
    df_sorted.ThermalStandard, 
    xlabel="Day of the Week Index", 
    ylabel="Daily System Thermal Generation (MWh)",
    legend=false
)
```


### Identify the top 10 hours of the month with the highest storage charging values for each Area
Spatially aggregating results by [`Area`](@extref) can reveal important spatial infromation and is frequently used for example in cases of transmission flow analysis. [`Area`](@extref) components often represent municipalities, villages or regional balancing areas of the real power system.

In this subsection, we aim to identify the top 10 hours of the month with the highest values of storage charging for each [`Area`](@extref) of the system.

To do this, we first define a selector for all [`EnergyReservoirStorage`](@extref) components, but instead of grouping them individually, we group them by the name of the [`Area`](@extref) to which their bus belongs. 

```@repl tutorial
storage_area_selector = make_selector(EnergyReservoirStorage; groupby = (x -> get_name(get_area(get_bus(x)))))
```

Next, using the selector we created, we compute the total active power flowing into the storage components of each [`Area`](@extref) using [`calc_active_power_in`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#PowerAnalytics.Metrics.calc_active_power_in), which is another one of [`PowerAnalytics.jl`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/) built-in metrics.

```@repl tutorial
df_charging = PA.calc_active_power_in(storage_area_selector, results_uc)
```

We observe that the resulting dataframe has only a single column for Area "3". This is due to the fact that the RTS-GMLC test system contains only a single storage component, which is located in Area "3". 

We then iterate through each [`Area`](@extref), sort its time series in descending order and extract the 10 timestamps with the highest charging values, an approach that is frequently used for storage capacity value calculations.

```@repl tutorial
area_columns = names(df_charging, Not("DateTime"))
for col in area_columns
    top_10_df = sort(df_charging[:, ["DateTime", col]], col, rev=true)[1:10, :]
    
    println("The top 10 hours of the month for Area $col are:")
    println(top_10_df)
    println() 
end
```

### Computing multiple metrics at once
We can efficiently compute multiple metrics and add their time series in the same summary table by using the [`compute_all`](@ref) function. In this case, we are interested in the three most common storage built-in metrics: 
- [`calc_active_power_in`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#PowerAnalytics.Metrics.calc_active_power_in): charging power into the storage device
- [`calc_active_power_out`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#PowerAnalytics.Metrics.calc_active_power_out): active power output of the storage device
- [`calc_stored_energy`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#PowerAnalytics.Metrics.calc_stored_energy): amount of energy stored 

We can reuse the `storage_area_selector` defined in the previous subsection to perform spatial aggregation by [`Area`](@extref). However, since the resulting summary table will contain a single column for each of the three metrics, we need to adjust the selector’s grouping using [`rebuild_selector`](@ref) to aggregate the time series across all storage components in the system, rather than by [`Area`](@extref).

```@repl tutorial
compute_all(results_uc,
    [PA.calc_active_power_in, PA.calc_active_power_out, PA.calc_stored_energy],
    [rebuild_selector(storage_area_selector, groupby = :all), rebuild_selector(storage_area_selector, groupby = :all), rebuild_selector(storage_area_selector, groupby = :all)],
    ["Storage Charging", "Storage Discharging", "Stored Energy"])
```

## Multiple Scenarios Results

In this section, instead of focusing on a single simulation scenario, we compare results across multiple scenarios. This allows us to explore how changing system component parameters can influence the simulation results. 

We begin by creating two new selectors, which aggregate the results for all [`RenewableDispatch`](@extref) and [`EnergyReservoirStorage`](@extref) components respectively.

```@repl tutorial
renewable_dispatch_selector_sys = make_selector(RenewableDispatch; groupby=:all)
storage_selector_sys = make_selector(EnergyReservoirStorage; groupby=:all)
```

Next, we list all the built-in metrics we have previously used in the single simulation results analysis section to be computed for each timestep. These are: 
- [`calc_active_power`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#PowerAnalytics.Metrics.calc_active_power)
- [`calc_curtailment`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#PowerAnalytics.Metrics.calc_curtailment)
- [`calc_active_power_in`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#PowerAnalytics.Metrics.calc_active_power_in)
- [`calc_active_power_out`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#PowerAnalytics.Metrics.calc_active_power_out)
- [`calc_stored_energy`](https://nrel-sienna.github.io/PowerAnalytics.jl/stable/reference/public/#PowerAnalytics.Metrics.calc_stored_energy)

We use the selectors `thermal_standard_selector_sys`, `renewable_dispatch_selector_sys` and `storage_selector_sys` to compute the active power of the thermal generators, the total curtailment of the renewable generators and the three storage specific metrics.

```@repl tutorial
time_computations = [
    (PA.calc_active_power, thermal_standard_selector_sys, "Thermal Generation (MWh)"),
    (PA.calc_curtailment, renewable_dispatch_selector_sys, "Renewables Curtailment (MWh)"),
    (PA.calc_active_power_in, storage_selector_sys, "Storage Charging (MWh)"),
    (PA.calc_active_power_out, storage_selector_sys, "Storage Discharging (MWh)"),
    (PA.calc_stored_energy, storage_selector_sys, "Storage SOC (MWh)"),
]
```

We are also interested in a set of metrics that are not available as time series, which we define in `timeless_computations`. 
These include the: 
- objective value 
- cumulative solve time 
- total memory allocated during the simulation

!!! tip

    Understanding memory usage across simulations is often particularly helpful when working with larger system models on [NREL's HPC systems](https://nrel.github.io/HPC/), since it can inform decisions regarding resource allocation, such as choosing between standard and high-memory partitions in order to avoid out-of-memory (OOM) errors.

```@repl tutorial
timeless_computations = [PA.calc_sum_objective_value, PA.calc_sum_solve_time, PA.calc_sum_bytes_alloc]
timeless_names = ["Objective Value", "Solve Time (s)", "Memory Allocated"];
```

Next, we define two utility functions, which form the core of our multi-scenario analysis pipeline and are executed for each individual scenario, namely:

- `analyze_one`: an analytics routine, which takes in the desired time-based and timeless metrics as arguments. It computes the selected time series metrics, aggregates them over time and appends the timeless metrics into a unified summary table. 

- `save_one`: saves the outputs from analyze_one to disk

```@repl tutorial
function analyze_one(results)
    time_series_analytics = compute_all(results, time_computations...)
    aggregated_time = aggregate_time(time_series_analytics)
    computed_all = compute_all(results, timeless_computations, nothing, timeless_names)
    all_time_analytics = hcat(aggregated_time, computed_all)
    return time_series_analytics, all_time_analytics
end

function save_one(output_dir, time_series_analytics, all_time_analytics)
    CSV.write(joinpath(output_dir, "summary_dataframe_new.csv"), time_series_analytics)
    CSV.write(joinpath(output_dir, "summary_stats_new.csv"), all_time_analytics)
end
```

Finally, we define the main post-processing routine that runs across all scenarios. After processing all scenarios, it concatenates the summaries into a single dataframe, which also gets exported to a csv file. 

```@repl tutorial
function post_processing(all_results)
    
    summaries = []
    for (scenario_name, results) in pairs(all_results)
        println("Computing for scenario: ", scenario_name)
        (time_series_analytics, all_time_analytics) = analyze_one(results)
        save_one(results.results_output_folder, time_series_analytics, all_time_analytics)
        push!(summaries, hcat(DataFrame("Scenario" => scenario_name), all_time_analytics))
    end

    summaries_df = vcat(summaries...)
    CSV.write("all_scenarios_summary_new.csv", summaries_df)
    return summaries_df
end
```

We run the `post_processing` routine with our multi-scenario results we previously defined. We can see the final summary table including all scenarios below:

```@repl tutorial
df = post_processing(results_all);
show(df; allcols=true)
```

Looking at the final dataframe, we can now easily compare the aggregated results of the selected metrics between the two simulation scenarios. 

Focusing on the thermal generation and renewable curtailment results for example, we observe a decrease of approximately 0.15% in total thermal generation and approximately 11.90% in renewable curtailment across the full simulation horizon and the entire system. The increased energy capacity of the storage device in the second scenario enables it to store more excess renewable energy rather than curtail it, which in turn reduces the need for thermal generation.