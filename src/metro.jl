
longitude(x::Point) = x.coords.lon.val
latitude(x::Point) = x.coords.lat.val

function strings2lonlat(x::Vector{S}) where {S <: AbstractString}
    latlon = @. split(x, ",")
    lon = @. parse(Float64, first(latlon))
    lat = @. parse(Float64, last(latlon))
    y = @. Point(LatLon{WGS84Latest}(lat, lon))
    return y
end

function meanlonlat(ps)
    lat = mean(latitude, ps)
    lon = mean(longitude, ps)
    return Point(LatLon{WGS84Latest}(lat, lon))
end

function metro_distance(ps, i::Int, j::Int)
    i, j = minmax(i, j)
    d = zero(Float64)
    for k in i:j-1
        d += norm(ps[k+1] - ps[k]).val
    end
    return d
end

function load_metro_stations(filename::String = METRO_STATIONS_FILE)
    # Load file as XML Node
    N = XML.read(filename, Node)
    folder = N[2][1][2]
    # Parse subway stations
    ch = children(folder)[2:end]
    dicts = Vector{Vector{Pair{Symbol, String}}}(undef, length(ch))
    for (i, c) in enumerate(ch)
        A = children(c[2][1])
        dicts[i] = [Symbol(a["name"]) => a[1].value for a in A]
        push!(dicts[i], :COORDS => value(c[3][1][1]))
    end
    # Build DataFrame
    stations_df = DataFrame(NamedTuple.(dicts))
    select!(stations_df, :LINEA, :NOMBRE, :COORDS)
    # Eliminate zeros in line numbers
    stations_df.LINEA = replace.(stations_df.LINEA, "0" => "")
    # Convert coordinates to LonLat
    stations_df.COORDS = strings2lonlat(stations_df.COORDS)
    # Group by name
    stations_gdf = groupby(stations_df, :NOMBRE)
    stations_df = combine(stations_gdf, :LINEA => Ref, :COORDS => meanlonlat,
        renamecols = false)

    return stations_df
end

function load_metro_lines(filename::String = METRO_LINES_FILE)
    # Load file as XML Node
    N = XML.read(filename, Node)
    folder = N[2][1][2]
    # Parse subway lines
    ch = children(folder)[2:end]
    dicts = Vector{Vector{Pair{Symbol, String}}}(undef, length(ch))
    for (i, c) in enumerate(ch)
        A = children(c[3][1])
        dicts[i] = [Symbol(a["name"]) => a[1].value for a in A]
        push!(dicts[i], :COORDS => value(c[4][1][1][1]))
    end
    # Build DataFrame
    lines_df = DataFrame(NamedTuple.(dicts))
    select!(lines_df, :LINEA, :RUTA, :COORDS)
    # Convert coordinates to LonLat
    latlon = split.(lines_df.COORDS, " ")
    lines_df.COORDS = strings2lonlat.(latlon)

    return lines_df
end

function metro_distance_matrix!(lines_df::DataFrame, stations_df::DataFrame)
    # Initialize distance matrix
    N = nrow(stations_df)
    D_metro = SparseMatrixCSC{Float64, Int16}(undef, N, N)
    # Iterate subway lines
    for line in eachrow(lines_df)
        stations = subset(stations_df, :LINEA => ByRow(x -> line.LINEA in x))
        index = map(s -> argmin(norm.(s .- line.COORDS)), stations.COORDS)
        perm = sortperm(index)
        permute!(stations, perm)
        permute!(index, perm)
        line.COORDS[index] = stations.COORDS
        for i in 1:length(index)-1
            s1 = findfirst(==(stations.NOMBRE[i]), stations_df.NOMBRE)
            s2 = findfirst(==(stations.NOMBRE[i+1]), stations_df.NOMBRE)
            d = metro_distance(line.COORDS, index[i], index[i+1])
            D_metro[s1, s2], D_metro[s2, s1] = d, d
        end
        line.COORDS = line.COORDS[index[1]:index[end]]
    end

    return D_metro
end

function metro_plot(cdmx_df::DataFrame, lines_df::DataFrame, stations_df::DataFrame,
    filename::String = "METRONETWORK.png")
    # Canvas
    fig = Figure()
    ax = Axis(fig[1, 1]; aspect = 1, xlabel = "Longitud [ᵒ]", ylabel = "Latitud [ᵒ]",
        xticks = -99.25:0.05:-98.95, yticks = 19.25:0.05:19.55)
    poly!(
        ax, cdmx_df.geom; color = (:white, 0.0), strokecolor = (:silver, 0.5),
        strokewidth = 0.5
    )
    # Metro lines
    for (i, line) in enumerate(eachrow(lines_df))
        lon = longitude.(line.COORDS)
        lat = latitude.(line.COORDS)
        lines!(ax, lon, lat, label = "", color = METRO_LINES_COLORS[i], linewidth = 2)
    end
    # Metro stations
    lon = longitude.(stations_df.COORDS)
    lat = latitude.(stations_df.COORDS)
    scatter!(ax, lon, lat, label = "", color = :black, markersize = 5)
    # Details
    xlims!(ax, -99.25, -98.95)
    ylims!(ax, 19.25, 19.55)
    resize_to_layout!(fig)
    save(filename, fig, pt_per_unit = 3)
end