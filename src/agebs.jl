
function load_agebs(filename::String = AGEBS_FILE)
    # Load .csv file as DataFrame
    agebs_df = DataFrame(CSV.File(filename))
    # Drop AGEBs: (i) without coordinates, (ii) in Hidalgo or (iii) rural
    dropmissing!(agebs_df, [:IDGEO, :Long, :Lat])
    filter!(r -> r.Entity != "Hidalgo" && r.Type != "Rural", agebs_df)
    # Convert coordinates to LonLat
    agebs_df.COORDS = @. Point(LatLon{WGS84Latest}(agebs_df.Lat, agebs_df.Long))
    # Keep only relevant columns
    select!(agebs_df, :IDGEO, :COORDS)

    return agebs_df
end

function link_metro_agebs!(agebs_df::DataFrame, stations_df::DataFrame,
    maximum_distance_to_metro::T = 10_000) where {T <: Real}
    # Keep only AGEBs close enough to metro stations
    agebs_df.DIST2METRO = map(c -> minimum(norm.(c .- stations_df.COORDS)).val,
        agebs_df.COORDS)
    filter!(:DIST2METRO => <=(maximum_distance_to_metro), agebs_df)
    select!(agebs_df, :IDGEO, :COORDS)
    # Sort by IDGEO
    sort!(agebs_df, :IDGEO)

    return nothing
end

function load_day(date::Date, agebs_df::DataFrame)
    # Load .csv file as DataFrame
    filename = joinpath(PACKAGE_DIRECTORY, "data/days", DAY_FILE_ROOT *
        Dates.format(date, "YYYY_mm_dd") * ".csv")
    day_df = DataFrame(CSV.File(filename))
    # Search sources and targets in agebs_df.IDGEO
    day_df.SOURCE = map(day_df.source) do s
        i = searchsorted(agebs_df.IDGEO, s)
        return isempty(i) ? zero(Int32) : Int32(first(i))
    end
    day_df.TARGET = map(day_df.target) do s
        i = searchsorted(agebs_df.IDGEO, s)
        return isempty(i) ? zero(Int32) : Int32(first(i))
    end
    filter!(r -> !iszero(r.SOURCE) && !iszero(r.TARGET), day_df)
    # Select relevant columns
    select!(day_df, :SOURCE, :TARGET, :w)
    # Assemble distance matrix
    D_day = sparse(day_df.SOURCE, day_df.TARGET, day_df.w)

    return D_day
end