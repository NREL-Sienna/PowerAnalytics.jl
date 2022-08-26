module PowerAnalytics

export make_fuel_dictionary
export get_generation_data
export get_load_data
export get_service_data
export categorize_data
export no_datetime

#I/O Imports
import Dates
import TimeSeries
import Requires
import DataFrames
import YAML
import DataStructures: OrderedDict, SortedDict
import PowerSystems
import InfrastructureSystems
import PowerSimulations

const PSY = PowerSystems
const IS = InfrastructureSystems
const PSI = PowerSimulations

include("definitions.jl")
include("get_data.jl")
include("fuel_results.jl")

greet() = print("Hello World!")

end # module PowerAnalytics
