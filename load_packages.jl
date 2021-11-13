# Load all necessary packages (repositories)
using DataFrames
using CSV
using Combinatorics
using Distributions
using JuMP
using GAMS
using Octavian
using LoopVectorization

# Load all necessary packages from the standard library module
using LinearAlgebra
using Random
using Statistics

## import all basic functions
include("functions/functions_basic.jl")
include("functions/functions_catalan.jl")
include("functions/functions_k-links.jl")
include("functions/functions_chisquare.jl")

## import the heuristic functions
include("heuristics/heuristic_qmkp.jl")
include("heuristics/optimisation_equalcap.jl")
include("heuristics/optimisation_buffercap.jl")
include("heuristics/heuristic_klinks.jl")
include("heuristics/heuristic_greedyseeds.jl")
include("heuristics/heuristic_greedypairs.jl")
include("heuristics/heuristic_bestselling.jl")
include("heuristics/heuristic_chisquare.jl")

## import the main comparison function
include("main_benchmark.jl")