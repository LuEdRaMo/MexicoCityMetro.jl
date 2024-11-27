using ArgParse, Distributed, JLD2, DataFrames, Dates, StatsBase

function parse_commandline()
    s = ArgParseSettings()

    # Program name (for usage & help screen)
    s.prog = "timeseries.jl"
    # Desciption (for help screen)
    s.description = "Explore the time dependence of MexicoCityMetro
    during January 2020"

    @add_arg_table! s begin
        "--line", "-l"
            help = "metro line to drop"
            arg_type = String
            default = "0"
        "--N", "-N"
            help = "number of Monte Carlo samples"
            arg_type = Int
            default = 50
        "--output", "-o"
            help = "output file (.jld2)"
            arg_type = String
            default = "timeseries.jld2"
    end

    s.epilog = """
        example:\n
        julia -p 10 -t 5 --project timeseries.jl -N 50 -o timeseries.jld2\n
    """

    return parse_args(s)
end

@everywhere begin
    using MexicoCityMetro
end

function main()

    # Initial time
    init_time = now()
    # Parse arguments from commandline
    parsed_args = parse_commandline()
    # Metro line to drop
    line::String = parsed_args["line"]
    # Number of Monte Carlo samples
    N::Int = parsed_args["N"]
    # Output file
    output::String = parsed_args["output"]
    # Print header
    println("MexicoCityMetro January 2020 timeseries")
    println("• Metro line to drop: ", line == "0" ? "None" : line)
    println("• Number of Monte Carlo samples: ", N)
    println("• Output file: ", output)
    println("• Number of workers: ", nworkers(), " (", Threads.nthreads(),
        " threads each)")

    # Preamble: load necessary data
    stations_df = load_metro_stations()
    lines_df = load_metro_lines()
    if line != "0"
        dropline!(stations_df, lines_df, line)
    end
    D_metro = metro_distance_matrix!(lines_df, stations_df)
    # Parameters
    maximum_distance_to_metro = 10_000.0 # 10 km
    metro_mean_velocity = 600.0 # 36 km/h
    traffic_mean_velocity = 300.0 # 18 km/h
    kmetro = 5.0
    ktraffic = 5.0
    αmetro = 5.0
    αtraffic = 1.0
    # Mobility network
    agebs_df = load_agebs()
    link_metro_agebs!(agebs_df, stations_df, maximum_distance_to_metro)
    mobility_df, D_mobility = mobility_network(D_metro, stations_df, agebs_df)
    # Time series
    iter = Date(2020, 1, 1):Day(1):Date(2020, 1, 31)
    result = Matrix{Float64}(undef, 23, length(iter))
    for (i, date) in enumerate(iter)
        # Day distance matrix
        D_day = load_day(date, agebs_df)
        # Monte Carlo
        SS = pmap(n -> mobility_mean_velocity(D_mobility, D_day, mobility_df;
            metro_mean_velocity, traffic_mean_velocity,
            kmetro, ktraffic, αmetro, αtraffic), 1:N)
        Sp = reduce(hcat, first.(SS))
        Sw = reduce(hcat, last.(SS))
        vs = (Sp ./ Sw) * (60 / 1_000) # km / h
        ps = mean(Sw, dims = 2)
        # Save results
        result[:, i] .= vcat(kmetro, αmetro, mean(vs, dims = 2), std(vs, dims = 2),
            ps / ps[1])
    end

    # Save results
    jldsave(output; result)
    # Final time
    final_time = now()
    println("• Run started ", init_time, " and finished ", final_time)

    nothing
end

main()