module MexicoCityMetro

using XML, LinearAlgebra, SparseArrays, JLD2
using Colors, CairoMakie
using DataFrames: DataFrame, ByRow, select!, groupby, combine, nrow, subset
using GeoStats: Point, LatLon, WGS84Latest
using StatsBase: mean
using Distributions: Pareto, truncated

export powerlaw
export longitude, latitude, load_metro_stations, load_metro_lines,
    metro_distance_matrix!, metro_plot

# Truncated Pareto distribution
powerlaw(tmin::T, tmax::T, α::T = 1.0) where {T <: Real} =
    truncated(Pareto(α, tmin), tmin, tmax)

include("constants.jl")
include("metro.jl")

end
