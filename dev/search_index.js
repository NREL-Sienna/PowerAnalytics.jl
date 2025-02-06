var documenterSearchIndex = {"docs":
[{"location":"api/PowerAnalytics/#PowerAnalytics","page":"PowerAnalytics","title":"PowerAnalytics","text":"","category":"section"},{"location":"api/PowerAnalytics/","page":"PowerAnalytics","title":"PowerAnalytics","text":"CurrentModule = PowerAnalytics\nDocTestSetup  = quote\n    using PowerAnalytics\nend","category":"page"},{"location":"api/PowerAnalytics/","page":"PowerAnalytics","title":"PowerAnalytics","text":"API documentation","category":"page"},{"location":"api/PowerAnalytics/","page":"PowerAnalytics","title":"PowerAnalytics","text":"Pages = [\"PowerAnalytics.md\"]","category":"page"},{"location":"api/PowerAnalytics/#Index","page":"PowerAnalytics","title":"Index","text":"","category":"section"},{"location":"api/PowerAnalytics/","page":"PowerAnalytics","title":"PowerAnalytics","text":"Pages = [\"PowerAnalytics.md\"]","category":"page"},{"location":"api/PowerAnalytics/#Exported","page":"PowerAnalytics","title":"Exported","text":"","category":"section"},{"location":"api/PowerAnalytics/","page":"PowerAnalytics","title":"PowerAnalytics","text":"Modules = [PowerAnalytics]\nPrivate = false","category":"page"},{"location":"api/PowerAnalytics/#PowerAnalytics.AGG_META_KEY","page":"PowerAnalytics","title":"PowerAnalytics.AGG_META_KEY","text":"Column metadata key whose value, if any, is additional information to be passed to aggregation functions. Values of nothing are equivalent to absence of the entry.\n\n\n\n\n\n","category":"constant"},{"location":"api/PowerAnalytics/#PowerAnalytics.DATETIME_COL","page":"PowerAnalytics","title":"PowerAnalytics.DATETIME_COL","text":"Name of the column that represents the time axis in computed DataFrames\n\n\n\n\n\n","category":"constant"},{"location":"api/PowerAnalytics/#PowerAnalytics.META_COL_KEY","page":"PowerAnalytics","title":"PowerAnalytics.META_COL_KEY","text":"Column metadata key whose value signifies whether the column is metadata. Metadata columns are excluded from get_data_cols and similar and can be used to represent things like a time aggregation.\n\n\n\n\n\n","category":"constant"},{"location":"api/PowerAnalytics/#PowerAnalytics.RESULTS_COL","page":"PowerAnalytics","title":"PowerAnalytics.RESULTS_COL","text":"Name of a column that represents whole-of-Results data\n\n\n\n\n\n","category":"constant"},{"location":"api/PowerAnalytics/#PowerAnalytics.SYSTEM_COL","page":"PowerAnalytics","title":"PowerAnalytics.SYSTEM_COL","text":"Name of a column that represents whole-of-System data\n\n\n\n\n\n","category":"constant"},{"location":"api/PowerAnalytics/#PowerAnalytics.ComponentSelectorTimedMetric","page":"PowerAnalytics","title":"PowerAnalytics.ComponentSelectorTimedMetric","text":"Time series Metrics defined on ComponentSelectors.\n\n\n\n\n\n","category":"type"},{"location":"api/PowerAnalytics/#PowerAnalytics.ComponentTimedMetric","page":"PowerAnalytics","title":"PowerAnalytics.ComponentTimedMetric","text":"ComponentSelectorTimedMetrics implemented by evaluating a function on each Component.\n\nArguments\n\nname::String: the name of the Metric\neval_fn: a function with signature (::IS.Results, ::Component; start_time::Union{Nothing, DateTime}, len::Union{Int, Nothing}) that returns a DataFrame representing the results for that Component\ncomponent_agg_fn: optional, a function to aggregate results between Components/ComponentSelectors, defaults to sum\ntime_agg_fn: optional, a function to aggregate results across time, defaults to sum\ncomponent_meta_agg_fn: optional, a callable to aggregate metadata across components, defaults to sum\ntime_meta_agg_fn: optional, a callable to aggregate metadata across time, defaults to sum\neval_zero: optional and rarely filled in, specifies what to do in the case where there are no components to contribute to a particular group; defaults to nothing, in which case the data is filled in from the identity element of component_agg_fn\n\n\n\n\n\n","category":"type"},{"location":"api/PowerAnalytics/#PowerAnalytics.CustomTimedMetric","page":"PowerAnalytics","title":"PowerAnalytics.CustomTimedMetric","text":"ComponentSelectorTimedMetrics implemented without drilling down to the base Components, just call the eval_fn directly.\n\nArguments\n\nname::String: the name of the Metric\neval_fn: a callable with signature (::IS.Results, ::Union{ComponentSelector, Component}; start_time::Union{Nothing, DateTime}, len::Union{Int, Nothing}) that returns a DataFrame representing the results for that Component\ntime_agg_fn: optional, a callable to aggregate results across time, defaults to sum\ntime_meta_agg_fn: optional, a callable to aggregate metadata across time, defaults to sum\n\n\n\n\n\n","category":"type"},{"location":"api/PowerAnalytics/#PowerAnalytics.Metric","page":"PowerAnalytics","title":"PowerAnalytics.Metric","text":"The basic type for all Metrics.\n\n\n\n\n\n","category":"type"},{"location":"api/PowerAnalytics/#PowerAnalytics.ResultsTimelessMetric","page":"PowerAnalytics","title":"PowerAnalytics.ResultsTimelessMetric","text":"Timeless Metrics with a single value per IS.Results instance\n\nArguments\n\n- `name::String`: the name of the `Metric`\n- `eval_fn`: a callable with signature `(::IS.Results,)` that returns a `DataFrame`\n  representing the results\n\n\n\n\n\n","category":"type"},{"location":"api/PowerAnalytics/#PowerAnalytics.SystemTimedMetric","page":"PowerAnalytics","title":"PowerAnalytics.SystemTimedMetric","text":"Time series Metrics defined on Systems.\n\nArguments\n\nname::String: the name of the Metric\neval_fn: a callable with signature (::IS.Results; start_time::Union{Nothing, DateTime}, len::Union{Int, Nothing}) that returns a DataFrame representing the results\ntime_agg_fn: optional, a callable to aggregate results across time, defaults to sum\ntime_meta_agg_fn: optional, a callable to aggregate metadata across time, defaults to sum\n\n\n\n\n\n","category":"type"},{"location":"api/PowerAnalytics/#PowerAnalytics.TimedMetric","page":"PowerAnalytics","title":"PowerAnalytics.TimedMetric","text":"Time series Metrics.\n\n\n\n\n\n","category":"type"},{"location":"api/PowerAnalytics/#PowerAnalytics.TimelessMetric","page":"PowerAnalytics","title":"PowerAnalytics.TimelessMetric","text":"Scalar-in-time Metrics.\n\n\n\n\n\n","category":"type"},{"location":"api/PowerAnalytics/#PowerAnalytics.aggregate_time-Tuple{DataFrames.AbstractDataFrame}","page":"PowerAnalytics","title":"PowerAnalytics.aggregate_time","text":"Given a DataFrame like that produced by compute_all, group by a function of the time axis, apply a reduction, and report the resulting aggregation indexed by the first timestamp in each group.\n\nArguments\n\ndf::DataFrames.AbstractDataFrame: the DataFrame to operate upon\ngroupby_fn = nothing: a callable that can be passed a DateTime; two rows will be in the same group iff their timestamps produce the same result under groupby_fn. Note that groupby_fn = month puts January 2023 and January 2024 into the same group whereas groupby_fn=(x -> (year(x), month(x))) does not.\ngroupby_col::Union{Nothing, AbstractString, Symbol} = nothing: specify a column name to report the result of groupby_fn in the output DataFrame, or nothing to not\nagg_fn = nothing: by default, the aggregation function (sum/mean/etc.) is specified by the Metric, which is read from the metadata of each column. If this metadata isn't found, one can specify a default aggregation function like sum here; if nothing, an error will be thrown.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.categorize_data-Tuple{Dict{Symbol, DataFrames.DataFrame}, Dict}","page":"PowerAnalytics","title":"PowerAnalytics.categorize_data","text":"Re-categorizes data according to an aggregation dictionary\n\nmakes no guarantee of complete data collection *\n\nExample\n\naggregation = PA.make_fuel_dictionary(results_uc.system)\ncategorize_data(gen_uc.data, aggregation)\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.compose_metrics","page":"PowerAnalytics","title":"PowerAnalytics.compose_metrics","text":"Given a list of metrics and a function that applies to their results to produce one result, create a new metric that computes the sub-metrics and applies the function to produce its own result.\n\nArguments\n\nname::String: the name of the new Metric\nreduce_fn: a callable that takes one value from each of the input Metrics and returns a single value that will be the result of this Metric. \"Value\" means a vector (not a DataFrame) in the case of TimedMetrics and a scalar for TimelessMetrics.\nmetrics: the input Metrics. It is currently not possible to combine TimedMetrics with TimelessMetrics, though it is possible to combine ComponentSelectorTimedMetrics with SystemTimedMetrics.\n\n\n\n\n\n","category":"function"},{"location":"api/PowerAnalytics/#PowerAnalytics.compute-Tuple{ComponentTimedMetric, InfrastructureSystems.Results, ComponentSelector}","page":"PowerAnalytics","title":"PowerAnalytics.compute","text":"Compute the given metric on the groups of the given ComponentSelector within the given set of results, returning a DataFrame with a DateTime column and a data column for each group. Exclude components marked as not available.\n\nArguments\n\nmetric::ComponentTimedMetric: the metric to compute\nresults::IS.Results: the results from which to fetch data\nselector::ComponentSelector: the ComponentSelector on whose subselectors to compute the metric\nstart_time::Union{Nothing, DateTime} = nothing: the time at which the resulting time series should begin\nlen::Union{Int, Nothing} = nothing: the number of steps in the resulting time series\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.compute-Tuple{ComponentTimedMetric, InfrastructureSystems.Results, PowerSystems.Component}","page":"PowerAnalytics","title":"PowerAnalytics.compute","text":"Compute the given metric on the given component within the given set of results, returning a DataFrame with a DateTime column and a data column labeled with the component's name.\n\nArguments\n\nmetric::ComponentTimedMetric: the metric to compute\nresults::IS.Results: the results from which to fetch data\ncomp::Component: the component on which to compute the metric\nstart_time::Union{Nothing, DateTime} = nothing: the time at which the resulting time series should begin\nlen::Union{Int, Nothing} = nothing: the number of steps in the resulting time series\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.compute-Tuple{CustomTimedMetric, InfrastructureSystems.Results, Union{ComponentSelector, PowerSystems.Component}}","page":"PowerAnalytics","title":"PowerAnalytics.compute","text":"Compute the given metric on the given component within the given set of results, returning a DataFrame with a DateTime column and a data column labeled with the component's name. Exclude components marked as not available.\n\nArguments\n\nmetric::CustomTimedMetric: the metric to compute\nresults::IS.Results: the results from which to fetch data\ncomp::Component: the component on which to compute the metric\nstart_time::Union{Nothing, DateTime} = nothing: the time at which the resulting time series should begin\nlen::Union{Int, Nothing} = nothing: the number of steps in the resulting time series\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.compute-Tuple{ResultsTimelessMetric, InfrastructureSystems.Results, Nothing}","page":"PowerAnalytics","title":"PowerAnalytics.compute","text":"Convenience method for compute_all; returns compute(metric, results)\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.compute-Tuple{ResultsTimelessMetric, InfrastructureSystems.Results}","page":"PowerAnalytics","title":"PowerAnalytics.compute","text":"Compute the given metric on the given set of results, returning a DataFrame with a single cell. Exclude components marked as not available.\n\nArguments\n\nmetric::ResultsTimelessMetric: the metric to compute\nresults::IS.Results: the results from which to fetch data\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.compute-Tuple{SystemTimedMetric, InfrastructureSystems.Results, Nothing}","page":"PowerAnalytics","title":"PowerAnalytics.compute","text":"Convenience method for compute_all; returns compute(metric, results; kwargs...)\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.compute-Tuple{SystemTimedMetric, InfrastructureSystems.Results}","page":"PowerAnalytics","title":"PowerAnalytics.compute","text":"Compute the given metric on the System associated with the given set of results, returning a DataFrame with a DateTime column and a data column.\n\nArguments\n\nmetric::SystemTimedMetric: the metric to compute\nresults::IS.Results: the results from which to fetch data\nstart_time::Union{Nothing, DateTime} = nothing: the time at which the resulting time series should begin\nlen::Union{Int, Nothing} = nothing: the number of steps in the resulting time series\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.compute_all","page":"PowerAnalytics","title":"PowerAnalytics.compute_all","text":"For each (metric, selector, col_name) tuple in zip(metrics, selectors, col_names), call compute and collect the results in a DataFrame with a single DateTime column. All selectors must yield exactly one group.\n\nArguments\n\nresults::IS.Results: the results from which to fetch data\nmetrics::Vector{<:TimedMetric}: the metrics to compute\nselectors: either a scalar or vector of Nothing/Component/ComponentSelector: the selectors on which to compute the metrics, or nothing for system/results metrics; broadcast if scalar\ncol_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing: a vector of names for the columns of ouput data. Entries of nothing default to the result of metric_selector_to_string; names = nothing is equivalent to an entire vector of nothing\nkwargs...: pass through to each compute call\n\n\n\n\n\n","category":"function"},{"location":"api/PowerAnalytics/#PowerAnalytics.compute_all-2","page":"PowerAnalytics","title":"PowerAnalytics.compute_all","text":"For each (metric, colname) tuple in `zip(metrics, colnames), call [compute`](@ref) and collect the results in a DataFrame.\n\nArguments\n\nresults::IS.Results: the results from which to fetch data\nmetrics::Vector{<:TimelessMetric}: the metrics to compute\nselectors: either a scalar or vector of Nothing/Component/ComponentSelector: the selectors on which to compute the metrics, or nothing for system/results metrics; broadcast if scalar\ncol_names::Union{Nothing, Vector{<:Union{Nothing, AbstractString}}} = nothing: a vector of names for the columns of ouput data. Entries of nothing default to the result of metric_selector_to_string; names = nothing is equivalent to an entire vector of nothing\nkwargs...: pass through to each compute call\n\n\n\n\n\n","category":"function"},{"location":"api/PowerAnalytics/#PowerAnalytics.compute_all-Tuple{InfrastructureSystems.Results, Vararg{Tuple{Union{TimedMetric, TimelessMetric}, Any, Any}}}","page":"PowerAnalytics","title":"PowerAnalytics.compute_all","text":"For each (metric, selector, col_name) tuple in computations, call compute and collect the results in a DataFrame with a single DateTime column. All selectors must yield exactly one group.\n\nArguments\n\nresults::IS.Results: the results from which to fetch data\ncomputations::(Tuple{<:T, Any, Any} where T <: Union{TimedMetric, TimelessMetric})...: a list of the computations to perform, where each element is a (metric, selector, col_name)wheremetricis the metric to compute,selectoris the ComponentSelector on which to compute the metric ornothingif not relevant, andcol_name` is the name for the output column of data or nothing to use the default\nkwargs...: pass through to each compute call\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.create_problem_results_dict","page":"PowerAnalytics","title":"PowerAnalytics.create_problem_results_dict","text":"Accept a directory that contains several results subdirectories (that each contain results, problems, etc. sub-subdirectories) and construct a sorted dictionary from String to SimulationProblemResults where the keys are the subdirectory names and the values are loaded results datasets.\n\nArguments\n\nresults_dir::AbstractString: the directory where results subdirectories can be found\nproblem::String: the name of the problem to load (e.g., \"UC\", \"ED\")\nscenarios::Union{Vector{AbstractString}, Nothing} = nothing: a list of scenario subdirectories to load, or nothing to load all the subdirectories\nkwargs...: keyword arguments to pass through to PSI.get_decision_problem_results\n\n\n\n\n\n","category":"function"},{"location":"api/PowerAnalytics/#PowerAnalytics.get_agg_meta-Tuple{Any, Any}","page":"PowerAnalytics","title":"PowerAnalytics.get_agg_meta","text":"Get the column's aggregation metadata; return nothing if there is none.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.get_agg_meta-Tuple{Any}","page":"PowerAnalytics","title":"PowerAnalytics.get_agg_meta","text":"Get the single data column's aggregation metadata; error on multiple data columns.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.get_data_cols-Tuple{DataFrames.AbstractDataFrame}","page":"PowerAnalytics","title":"PowerAnalytics.get_data_cols","text":"Select the names of the data columns of the DataFrame, i.e., those that are not DateTime and not metadata.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.get_data_df-Tuple{DataFrames.AbstractDataFrame}","page":"PowerAnalytics","title":"PowerAnalytics.get_data_df","text":"Select the data columns of the DataFrame as a DataFrame without copying.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.get_data_mat-Tuple{DataFrames.AbstractDataFrame}","page":"PowerAnalytics","title":"PowerAnalytics.get_data_mat","text":"Select the data columns of the DataFrame as a Matrix with copying.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.get_data_vec-Tuple{DataFrames.AbstractDataFrame}","page":"PowerAnalytics","title":"PowerAnalytics.get_data_vec","text":"Select the data column of the DataFrame as a vector without copying, errors if more than one.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.get_time_df-Tuple{DataFrames.AbstractDataFrame}","page":"PowerAnalytics","title":"PowerAnalytics.get_time_df","text":"Select the DateTime column of the DataFrame as a one-column DataFrame without copying.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.get_time_vec-Tuple{DataFrames.AbstractDataFrame}","page":"PowerAnalytics","title":"PowerAnalytics.get_time_vec","text":"Select the DateTime column of the DataFrame as a Vector without copying.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.hcat_timed_dfs-Tuple{Vararg{DataFrames.DataFrame}}","page":"PowerAnalytics","title":"PowerAnalytics.hcat_timed_dfs","text":"If the time axes match across all the DataFrames, horizontally concatenate them and remove the duplicate time axes. If not, throw an error\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.is_col_meta-Tuple{Any, Any}","page":"PowerAnalytics","title":"PowerAnalytics.is_col_meta","text":"Check whether a column is metadata\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.make_fuel_dictionary-Tuple{PowerSystems.System, Dict{NamedTuple, String}}","page":"PowerAnalytics","title":"PowerAnalytics.make_fuel_dictionary","text":"generators = make_fuel_dictionary(system::PSY.System, mapping::Dict{NamedTuple, String})\n\nThis function makes a dictionary of fuel type and the generators associated.\n\nArguments\n\nsys::PSY.System: the system that is used to create the results\nresults::IS.Results: results\n\nKey Words\n\ncategories::Dict{String, NamedTuple}: if stacking by a different category is desired\n\nExample\n\nresults = solveopmodel!(OpModel) generators = makefueldictionary(sys)\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.metric_selector_to_string-Tuple{Metric, Union{ComponentSelector, PowerSystems.Component}}","page":"PowerAnalytics","title":"PowerAnalytics.metric_selector_to_string","text":"Canonical way to represent a (Metric, ComponentSelector) or (Metric, Component) pair as a string.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.parse_generator_categories-Tuple{Any}","page":"PowerAnalytics","title":"PowerAnalytics.parse_generator_categories","text":"Use parse_generator_mapping_file to parse a generator_mapping.yaml file into a dictionary of ComponentSelector, excluding categories in the 'non_generators' list in metadata\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.parse_generator_mapping_file-Tuple{Any}","page":"PowerAnalytics","title":"PowerAnalytics.parse_generator_mapping_file","text":"Parse a generator_mapping.yaml file into a dictionary of ComponentSelectors and a dictionary of metadata if present\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.parse_injector_categories-Tuple{Any}","page":"PowerAnalytics","title":"PowerAnalytics.parse_injector_categories","text":"Use parse_generator_mapping_file to parse a generator_mapping.yaml file into a dictionary of all ComponentSelectors\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.rebuild_metric-Tuple{T} where T<:Metric","page":"PowerAnalytics","title":"PowerAnalytics.rebuild_metric","text":"Returns a Metric identical to the input metric except with the changes to its fields specified in the keyword arguments.\n\nExamples\n\nMake a variant of calc_active_power that averages across components rather than summing:\n\nusing PowerAnalytics.Metrics\ncalc_active_power_mean = rebuild_metric(calc_active_power; component_agg_fn = mean)\n# (now calc_active_power_mean works as a standalone, callable metric)\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.set_agg_meta!-Tuple{Any, Any, Any}","page":"PowerAnalytics","title":"PowerAnalytics.set_agg_meta!","text":"Set the column's aggregation metadata.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.set_agg_meta!-Tuple{Any, Any}","page":"PowerAnalytics","title":"PowerAnalytics.set_agg_meta!","text":"Set the single data column's aggregation metadata; error on multiple data columns.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.set_col_meta!","page":"PowerAnalytics","title":"PowerAnalytics.set_col_meta!","text":"Mark a column as metadata\n\n\n\n\n\n","category":"function"},{"location":"api/PowerAnalytics/#PowerAnalytics.unweighted_sum-Tuple{Any}","page":"PowerAnalytics","title":"PowerAnalytics.unweighted_sum","text":"A version of sum that ignores a second argument, for use where aggregation metadata is at play\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.weighted_mean-Tuple{Any, Any}","page":"PowerAnalytics","title":"PowerAnalytics.weighted_mean","text":"Compute the mean of values weighted by the corresponding entries of weights. Arguments may be vectors or vectors of vectors. A weight of 0 cancels out a value of NaN.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#Internal","page":"PowerAnalytics","title":"Internal","text":"","category":"section"},{"location":"api/PowerAnalytics/","page":"PowerAnalytics","title":"PowerAnalytics","text":"Modules = [PowerAnalytics]\nPublic = false","category":"page"},{"location":"api/PowerAnalytics/#PowerAnalytics.EntryType","page":"PowerAnalytics","title":"PowerAnalytics.EntryType","text":"The various key entry types that can be used to make a PSI.OptimizationContainerKey\n\n\n\n\n\n","category":"type"},{"location":"api/PowerAnalytics/#PowerAnalytics.SystemEntryType","page":"PowerAnalytics","title":"PowerAnalytics.SystemEntryType","text":"The various key entry types that can work with a System\n\n\n\n\n\n","category":"type"},{"location":"api/PowerAnalytics/#PowerAnalytics.NoResultError","page":"PowerAnalytics","title":"PowerAnalytics.NoResultError","text":"The metric does not have a result for the Component/ComponentSelector/etc. on which it is being called.\n\n\n\n\n\n","category":"type"},{"location":"api/PowerAnalytics/#PowerAnalytics.combine_categories-Tuple{Union{Dict{String, DataFrames.DataFrame}, Dict{Symbol, DataFrames.DataFrame}}}","page":"PowerAnalytics","title":"PowerAnalytics.combine_categories","text":"aggregates and combines data into single DataFrame\n\nExample\n\nPG.combine_categories(gen_uc.data)\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.get_generator_category-Tuple{Any, Any, Any, Any, Dict{NamedTuple, String}}","page":"PowerAnalytics","title":"PowerAnalytics.get_generator_category","text":"Return the generator category for this fuel and unit_type.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.get_generator_mapping","page":"PowerAnalytics","title":"PowerAnalytics.get_generator_mapping","text":"Return a dict where keys are a tuple of input parameters (fuel, unit_type) and values are generator types.\n\n\n\n\n\n","category":"function"},{"location":"api/PowerAnalytics/#PowerAnalytics.lookup_gentype-Tuple{AbstractString}","page":"PowerAnalytics","title":"PowerAnalytics.lookup_gentype","text":"Parse the gentype to a type. This is done by first checking whether gentype is qualified (ModuleName.TypeName). If so, the module is fetched from the Main scope and the type name is fetched from the module. If not, we default to fetching from PowerSystems for convenience.\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.make_component_metric_from_entry-Tuple{String, Type{<:Union{InfrastructureSystems.Optimization.AuxVariableType, InfrastructureSystems.Optimization.ExpressionType, InfrastructureSystems.Optimization.InitialConditionType, InfrastructureSystems.Optimization.ParameterType, InfrastructureSystems.Optimization.VariableType}}}","page":"PowerAnalytics","title":"PowerAnalytics.make_component_metric_from_entry","text":"Convenience function to convert an EntryType to a function and make a ComponentTimedMetric from it\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.make_entry_kwargs-Tuple{Vector{<:Tuple}}","page":"PowerAnalytics","title":"PowerAnalytics.make_entry_kwargs","text":"Sort a vector of key tuples into variables, parameters, etc. like PSI.load_results! wants\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.make_key","page":"PowerAnalytics","title":"PowerAnalytics.make_key","text":"Create a PSI.OptimizationContainerKey from the given key entry type and component.\n\nArguments\n\nentry::Type{<:EntryType}: the key entry\ncomponent (::Type{<:Union{Component, PSY.System}} or ::Type{<:Component} depending on the key type): the component type\n\n\n\n\n\n","category":"function"},{"location":"api/PowerAnalytics/#PowerAnalytics.make_system_metric_from_entry-Tuple{String, Type{<:Union{InfrastructureSystems.Optimization.ExpressionType, InfrastructureSystems.Optimization.VariableType}}}","page":"PowerAnalytics","title":"PowerAnalytics.make_system_metric_from_entry","text":"Convenience function to convert a SystemEntryType to a function and make a SystemTimedMetric from it\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.read_component_result-Tuple{InfrastructureSystems.Results, Type{<:Union{InfrastructureSystems.Optimization.AuxVariableType, InfrastructureSystems.Optimization.ExpressionType, InfrastructureSystems.Optimization.InitialConditionType, InfrastructureSystems.Optimization.ParameterType, InfrastructureSystems.Optimization.VariableType}}, PowerSystems.Component}","page":"PowerAnalytics","title":"PowerAnalytics.read_component_result","text":"Given an EntryType and a Component, fetch a single column of results\n\n\n\n\n\n","category":"method"},{"location":"api/PowerAnalytics/#PowerAnalytics.read_system_result-Tuple{InfrastructureSystems.Results, Type{<:Union{InfrastructureSystems.Optimization.ExpressionType, InfrastructureSystems.Optimization.VariableType}}}","page":"PowerAnalytics","title":"PowerAnalytics.read_system_result","text":"Given an EntryType that applies to the System, fetch a single column of results\n\n\n\n\n\n","category":"method"},{"location":"#PowerAnalytics.jl","page":"Introduction","title":"PowerAnalytics.jl","text":"","category":"section"},{"location":"#Overview","page":"Introduction","title":"Overview","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"PowerAnalytics.jl is a Julia package designed to support power system simulation results analysis. It relies on results generated from PowerSimulations.jl. PowerAnalytics provides the data collection, aggregation, and subsetting for PowerGraphics.jl.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"The documentation is still a work in progress.","category":"page"},{"location":"#Installation","page":"Introduction","title":"Installation","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"The latest stable release of PowerAnalytics can be installed using the Julia package manager with","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"] add PowerAnalytics","category":"page"}]
}
