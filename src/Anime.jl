# SPDX-License-Identifier: MIT

# Anime - Atmospheric aNd Instrumental models in the Measurement Equation
"""Anime: Atmospheric aNd Instrumental Models in the Measurement Equation
"""
module Anime

using Plots, ColorSchemes, LaTeXStrings
using Tables
using Logging
using CSV
using HDF5
using YAML
using Random
using Statistics
using DataFrames
using Distributions
using LinearAlgebra
using Casacore.Tables: Tables as CCTables, Table as CCTable
using PythonCall

quanta = pyimport("casatools" => "quanta")
importuvfits = pyimport("casatasks" => "importuvfits")
exportuvfits = pyimport("casatasks" => "exportuvfits")
table = pyimport("casatools" => "table")
measures = pyimport("casatools" => "measures")
simulator = pyimport("casatools" => "simulator")
qa = quanta()
tb = table()
me = measures()
sm = simulator()

include("storageutils/storageutils.jl")
include("coherency/coherency.jl")
include("atmosphericmodels/atmosphericmodels.jl")
include("polarizationmodels/polarizationmodels.jl")
include("beammodels/beammodels.jl")
include("gainmodels/gainmodels.jl")
include("noisemodels/noisemodels.jl")
include("stats/stats.jl")
include("util.jl")
include("plots.jl")

end
