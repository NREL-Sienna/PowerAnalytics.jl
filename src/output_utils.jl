# TODO move this to PowerSimulations to replace its hardcoding of :DateTime
"Name of the column that represents the time axis in computed DataFrames"
const DATETIME_COL::String = "DateTime"

"""
Column metadata key whose value signifies whether the column is metadata. Metadata columns
are excluded from `data_cols` and similar and can be used to represent things like a time
aggregation.
"""
const META_COL_KEY::String = "meta_col"

"Name of a column that represents whole-of-`System` data"
const SYSTEM_COL::String = "System"

"Name of a column that represents whole-of-`Results` data"
const RESULTS_COL::String = "Results"

"""
Column metadata key whose value, if any, is additional information to be passed to
aggregation functions. Values of `nothing` are equivalent to absence of the entry.
"""
const AGG_META_KEY::String = "agg_meta"

"Check whether a column is metadata"
is_col_meta(df, colname) = get(colmetadata(df, colname), META_COL_KEY, false)

"Mark a column as metadata"
set_col_meta!(df, colname, val = true) =
    colmetadata!(df, colname, META_COL_KEY, val; style = :note)

"Get the column's aggregation metadata; return `nothing` if there is none."
get_agg_meta(df, colname) = get(colmetadata(df, colname), AGG_META_KEY, nothing)

"Get the single data column's aggregation metadata; error on multiple data columns."
function get_agg_meta(df)
    my_data_cols = data_cols(df)
    (length(my_data_cols) == 1) && return get_agg_meta(df, first(my_data_cols))
    throw(
        ArgumentError(
            "DataFrame has $(size(the_data, 2)) columns of data, must specify a column name",
        ),
    )
end

"Set the column's aggregation metadata."
set_agg_meta!(df, colname, val) =
    colmetadata!(df, colname, AGG_META_KEY, val; style = :note)

"Set the single data column's aggregation metadata; error on multiple data columns."
function set_agg_meta!(df, val)
    my_data_cols = data_cols(df)
    (length(my_data_cols) == 1) && return set_agg_meta!(df, first(my_data_cols), val)
    throw(
        ArgumentError(
            "DataFrame has $(size(the_data, 2)) columns of data, must specify a column name",
        ),
    )
end

# TODO test that mutating the selection mutates the original
"Select the `DateTime` column of the `DataFrame` as a one-column `DataFrame` without copying."
time_df(df::DataFrames.AbstractDataFrame) =
    DataFrames.select(df, DATETIME_COL; copycols = false)

"Select the `DateTime` column of the `DataFrame` as a `Vector` without copying."
time_vec(df::DataFrames.AbstractDataFrame) = df[!, DATETIME_COL]

"""
Select the names of the data columns of the `DataFrame`, i.e., those that are not `DateTime`
and not metadata.
"""
data_cols(df::DataFrames.AbstractDataFrame) =
    filter(
        (
            colname ->
                (colname != DATETIME_COL) &&
                    !is_col_meta(df, colname)
        ),
        names(df))

"Select the data columns of the `DataFrame` as a `DataFrame` without copying."
data_df(df::DataFrames.AbstractDataFrame) =
    DataFrames.select(df, data_cols(df); copycols = false)

"Select the data column of the `DataFrame` as a vector without copying, errors if more than one."
function data_vec(df::DataFrames.AbstractDataFrame)
    the_data = data_df(df)
    (size(the_data, 2) > 1) && throw(
        ArgumentError(
            "DataFrame has $(size(the_data, 2)) columns of data, consider using data_mat",
        ),
    )
    return the_data[!, 1]
end

"Select the data columns of the `DataFrame` as a `Matrix` with copying."
data_mat(df::DataFrames.AbstractDataFrame) = Matrix(data_df(df))

# TODO test allow_missing behavior
function _extract_common_time(dfs::DataFrames.AbstractDataFrame...;
    allow_missing = true, ex_fn::Function = time_vec)
    time_cols = ex_fn.(dfs)
    allow_missing || !any([any(ismissing.(ex_fn(tc))) for tc in time_cols]) ||
        throw(ErrorException("Missing time columns"))
    # Candidate time column is the one with the most non-missing values
    time_col = argmax(x -> count(!ismissing, Array(x)), time_cols)
    # Other time columns must either be the same or [nothing]
    # TODO come up with a more informative error here
    all([
        isequal(sub, time_col) ||
            (all(ismissing.(Array(sub))) && size(sub, 1) == 1) for sub in time_cols
    ]) ||
        throw(ErrorException("Mismatched time columns"))
    return time_col
end

# TODO test
function _broadcast_time(data_cols, time_col; allow_unitary = true)
    size(data_cols, 1) == size(time_col, 1) && return data_cols
    (allow_unitary && size(data_cols, 1) == 1) ||
        throw(ErrorException("Individual data column does not match aggregate time column"))
    return repeat(data_cols, size(time_col, 1))  # Preserves metadata
end

"""
If the time axes match across all the `DataFrames`, horizontally concatenate them and remove
the duplicate time axes. If not, throw an error
"""
function hcat_timed(vals::DataFrame...)  # TODO incorporate allow_missing
    time_col = _extract_common_time(vals...; ex_fn = time_df)
    broadcasted_vals = [data_df(sub) for sub in _broadcast_time.(vals, Ref(time_col))]
    return hcat(time_col, broadcasted_vals...)
end
