using Test
using TestSetExtensions
using Logging
using Dates
using DataFrames
using DataStructures
import InfrastructureSystems
import InfrastructureSystems: Deterministic, Probabilistic, Scenarios, Forecast
using PowerSystems
using PowerAnalytics
using PowerSimulations
using GLPK
using TimeSeries
using StorageSystemsSimulations
using HydroPowerSimulations

const PA = PowerAnalytics
const IS = InfrastructureSystems
const PSY = PowerSystems
const PSI = PowerSimulations
const LOG_FILE = "PowerAnalytics-test.log"

const BASE_DIR = dirname(dirname(pathof(PowerAnalytics)))
const TEST_DIR = joinpath(BASE_DIR, "test")
const TEST_OUTPUTS = joinpath(BASE_DIR, "test", "test_results")
!isdir(TEST_OUTPUTS) && mkdir(TEST_OUTPUTS)
const TEST_RESULT_DIR = joinpath(TEST_OUTPUTS, "results")
!isdir(TEST_RESULT_DIR) && mkdir(TEST_RESULT_DIR)
const TEST_SIM_NAME = "results_sim"
const TEST_DUPLICATE_RESULTS_NAME = "temp_duplicate_results"

import PowerSystemCaseBuilder
const PSB = PowerSystemCaseBuilder

LOG_LEVELS = Dict(
    "Debug" => Logging.Debug,
    "Info" => Logging.Info,
    "Warn" => Logging.Warn,
    "Error" => Logging.Error,
)

include(joinpath(BASE_DIR, "test", "test_data", "results_data.jl"))
