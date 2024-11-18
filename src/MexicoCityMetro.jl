module MexicoCityMetro

using CSV, XML, LinearAlgebra, SparseArrays, Dates, JLD2, DelaunayTriangulation, Graphs
using Colors, CairoMakie
using DataFrames: DataFrame, ByRow, select!, groupby, combine, nrow, subset,
    dropmissing!, sort!
using GeoStats: Point, LatLon, WGS84Latest
using StatsBase: mean
using Distributions: Pareto, truncated

import Graphs.Parallel

export powerlaw, printpath
export longitude, latitude, load_metro_stations, load_metro_lines,
    metro_distance_matrix!, metro_plot
export load_agebs, link_metro_agebs!, load_day
export mobility_network, mobility_plot, time_matrix, mobility_mean_velocity

# Truncated Pareto distribution
powerlaw(tmin::T, tmax::T, α::T = 1.0) where {T <: Real} =
    truncated(Pareto(α, tmin), tmin, tmax)

function printpath(index::Vector{String}, g::AbstractGraph, i::Int, j::Int,
    distmx::AbstractMatrix)
    vs = a_star(g, i, j, distmx)
    for v in vs
        println(index[v.src], " => ", index[v.dst])
    end
    return nothing
end

include("constants.jl")
include("metro.jl")
include("agebs.jl")
include("mobility.jl")

end
