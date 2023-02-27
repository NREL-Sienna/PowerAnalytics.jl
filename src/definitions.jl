
NEGATIVE_PARAMETERS = [PSY.StaticLoad]
SUPPORTED_CURTAILMENT_PARAMETERS = [PSI.ActivePowerTimeSeriesParameter]

SUPPORTED_CURTAILMENT_VARIABLES = [PSI.ActivePowerVariable]
SUPPORTED_LOAD_VARIABLES = [PSI.ActivePowerVariable]
SUPPORTED_STORAGE_VARIABLES = [PSI.ActivePowerInVariable, PSI.ActivePowerOutVariable]
SUPPORTED_SERVICE_VARIABLES = [PSI.ActivePowerReserveVariable]

SUPPORTED_OVERGENERATION_VARIABLE = PSI.SystemBalanceSlackDown
SUPPORTED_UNSERVEDENERGY_VARIABLES = PSI.SystemBalanceSlackUp
BALANCE_SLACKVARS = Dict(
    SUPPORTED_OVERGENERATION_VARIABLE => "Over Generation",
    SUPPORTED_UNSERVEDENERGY_VARIABLES => "Unserved Energy",
)

LOAD_RENAMING = Dict(
    :ActivePowerTimeSeriesParameter__StandardLoad => :Load,
    :ActivePowerTimeSeriesParameter__PowerLoad => :Load,
    :ActivePowerTimeSeriesParameter__ExponentialLoad => :Load,
    :ActivePowerVariable__StandardLoad => :Dispatchable_Load,
    :ActivePowerVariable__PowerLoad => :Dispatchable_Load,
    :ActivePowerVariable__ExponentialLoad => :Dispatchable_Load,
)

GENERATOR_MAPPING_FILE =
    joinpath(dirname(dirname(pathof(PowerAnalytics))), "deps", "generator_mapping.yaml")
