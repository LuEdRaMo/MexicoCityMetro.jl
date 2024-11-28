
function mobility_network(D_metro::SparseMatrixCSC{Float64, Int16},
    stations_df::DataFrame, agebs_df::DataFrame)
    # Mobility dataframe
    mobility_df = DataFrame(ID = vcat(stations_df.NOMBRE, agebs_df.IDGEO),
        COORDS = vcat(stations_df.COORDS, agebs_df.COORDS))
    # Metro conections are fixed segments
    I_metro, J_metro, _ = findnz(D_metro)
    S_metro = Set(@. tuple(Int(I_metro), Int(J_metro)))
    # Delaunay triangulation
    lon = longitude.(mobility_df.COORDS)
    lat = latitude.(mobility_df.COORDS)
    points = hcat(lon, lat)'
    tri = triangulate(points; segments = S_metro)
    # Initialize distance matrix
    N_metro = nrow(stations_df)
    N_mobility = nrow(mobility_df)
    D_mobility = SparseMatrixCSC{Float64, Int16}(undef, N_mobility, N_mobility)
    # Fill distance matrix
    for e in each_solid_edge(tri)
        i, j = e
        if i ≤ N_metro && j ≤ N_metro
            D_mobility[i, j], D_mobility[j, i] = D_metro[i, j], D_metro[j, i]
        else
            d = norm(mobility_df.COORDS[i] - mobility_df.COORDS[j]).val
            D_mobility[i, j], D_mobility[j, i] = d, d
        end
    end

    return mobility_df, D_mobility
end

function mobility_plot(D_mobility::SparseMatrixCSC{Float64, Int16},
    cdmx_df::DataFrame, mobility_df::DataFrame, lines_df::DataFrame,
    filename::String = "MOBILITYNETWORK.png",
    dcolor = x -> :navajowhite)
    # Number of metro stations
    N_metro = findfirst(startswith("0"), mobility_df.ID) - 1
    # Longitude and latitude
    lon = longitude.(mobility_df.COORDS)
    lat = latitude.(mobility_df.COORDS)
    # Canvas
    fig = Figure()
    ax = Axis(fig[1, 1]; aspect = 1, xlabel = "Longitud [ᵒ]", ylabel = "Latitud [ᵒ]",
        xticks = -99.35:0.1:-98.85, yticks = 19.15:0.05:19.65)
    poly!(
        ax, cdmx_df.geom; color = (:white, 0.0), strokecolor = (:silver, 0.5),
        strokewidth = 0.5
    )
    # AGEBs plot
    dist2metro = map(c -> minimum(norm.(c .- mobility_df.COORDS[1:N_metro])).val,
        mobility_df.COORDS)
    I, J, _ = findnz(D_mobility)
    for (i, j) in zip(I, J)
        (i ≤ N_metro && j ≤ N_metro) && continue
        (i < j) && continue
        d = min(dist2metro[i], dist2metro[j])
        lines!(ax, [lon[i], lon[j]], [lat[i], lat[j]], label = "", color = dcolor(d),
        linewidth = 1)
    end
    scatter!(ax, lon[N_metro+1:end], lat[N_metro+1:end], label = "",
        color = :navajowhite, markersize = 0.75, marker = :rect)
    # Metro lines
    for (i, line) in enumerate(eachrow(lines_df))
        _lon_ = longitude.(line.COORDS)
        _lat_ = latitude.(line.COORDS)
        lines!(ax, _lon_, _lat_, label = "", color = METRO_LINES_COLORS[line.LINEA],
            linewidth = 2)
    end
    # Metro stations
    scatter!(ax, lon[1:N_metro], lat[1:N_metro], label = "", color = :black,
        markersize = 4)
    # Details
    xlims!(ax, -99.35, -98.85)
    ylims!(ax, 19.15, 19.65)
    resize_to_layout!(fig)
    save(filename, fig, pt_per_unit = 3)
end

function time_matrix(D_mobility::SparseMatrixCSC{Float64, Int16},
    mobility_df::DataFrame,
    metro_mean_velocity::T = METRO_MEAN_VELOCITY,
    traffic_mean_velocity::T = TRAFFIC_MEAN_VELOCITY,
    kmetro::T = 2.0, ktraffic::T = 2.0,
    αmetro::T = 1.0, αtraffic::T = 1.0) where {T <: Real}
    # Initialize distance matrix
    N_metro = findfirst(startswith("0"), mobility_df.ID) - 1
    N_mobility = size(D_mobility, 1)
    T_mobility = SparseMatrixCSC{Float64, Int16}(undef, N_mobility, N_mobility)
    # Fill time matrix
    I, J, V = findnz(D_mobility)
    for (i, j, d) in zip(I, J, V)
        if i ≤ N_metro && j ≤ N_metro
            _t_ = d / metro_mean_velocity
            dist = powerlaw(_t_, kmetro * _t_, αmetro)
        else
            _t_ = d / traffic_mean_velocity
            dist = powerlaw(_t_, ktraffic * _t_, αtraffic)
        end
        t = rand(dist)
        T_mobility[i, j], T_mobility[j, i] = t, t
    end

    return T_mobility
end

function mobility_mean_velocity(D_mobility::SparseMatrixCSC{Float64, Int16},
    D_day::SparseMatrixCSC{Float64, Int32}, mobility_df::DataFrame;
    metro_mean_velocity::T = METRO_MEAN_VELOCITY,
    traffic_mean_velocity::T = TRAFFIC_MEAN_VELOCITY,
    kmetro::T = 2.0, ktraffic::T = 2.0,
    αmetro::T = 1.0, αtraffic::T = 1.0) where {T <: Real}
    # Time matrix
    T_mobility = time_matrix(D_mobility, mobility_df, metro_mean_velocity,
        traffic_mean_velocity, kmetro, ktraffic, αmetro, αtraffic)
    # Mobility network
    N_metro = findfirst(startswith("0"), mobility_df.ID) - 1
    N_mobility = size(T_mobility, 1)
    g_mobility = SimpleGraph{Int16}(T_mobility)
    # Iterate shortest paths
    paths = Parallel.dijkstra_shortest_paths(g_mobility, N_metro+1:N_mobility,
        T_mobility)
    times = view(paths.dists, :, N_metro+1:N_mobility)
    I, J, W = findnz(D_day)
    # 400 m, 1 km, 5 km, 10 km, 15 km, 20 km, 25 km
    bounds = [400, 1_000, 5_000, 10_000, 15_000, 20_000, 25_000]
    Sp, Sw = zeros(Float64, 7), zeros(Float64, 7)
    for (i, j, w) in zip(I, J, W)
        d = norm(mobility_df.COORDS[i+N_metro] - mobility_df.COORDS[j+N_metro]).val
        t = times[i, j]
        mask = d .> bounds
        Sp[mask] .+= w * (d/t)
        Sw[mask] .+= w
    end

    return Sp, Sw
end