using ArgParse, Distributed, JLD2, DataFrames, Dates, StatsBase
using Compat: LogRange

function parse_commandline()
    s = ArgParseSettings()

    # Program name (for usage & help screen)
    s.prog = "gridsearch.jl"
    # Desciption (for help screen)
    s.description = "Explore the parameter space of MexicoCityMetro"

    @add_arg_table! s begin
        "--N", "-N"
            help = "number of Monte Carlo samples"
            arg_type = Int
            default = 50
        "--output", "-o"
            help = "output file (.jld2)"
            arg_type = String
            default = "gridsearch.jld2"
    end

    s.epilog = """
        example:\n
        julia -p 10 -t 5 --project gridsearch.jl -N 50 -o gridsearch.jld2\n
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
    # Number of Monte Carlo samples
    N::Int = parsed_args["N"]
    # Output file
    output::String = parsed_args["output"]
    # Print header
    println("MexicoCityMetro gridsearch")
    println("• Number of Monte Carlo samples: ", N)
    println("• Output file: ", output)
    println("• Number of workers: ", nworkers(), "(", Threads.nthreads(),
        " threads each)")

    # Preamble: load necessary data
    stations_df = load_metro_stations()
    lines_df = load_metro_lines()
    D_metro = metro_distance_matrix!(lines_df, stations_df)
    # Parameters
    maximum_distance_to_metro = 10_000 # 10 km
    metro_mean_velocity = 600.0 # 36 km/h
    traffic_mean_velocity = 300.0 # 18 km/h
    kmetros = 2:10
    ktraffic = 5.0
    αmetros = collect(0.0:10.0); αmetros[1] = eps()
    αtraffic = 1.0
    # Mobility network
    agebs_df = load_agebs()
    link_metro_agebs!(agebs_df, stations_df, maximum_distance_to_metro)
    mobility_df, D_mobility = mobility_network(D_metro, stations_df, agebs_df)
    D_day = load_day(Date(2020, 1, 1), agebs_df)
    # Grid search
    iter = Iterators.product(kmetros, αmetros)
    result = Matrix{Float64}(undef, 4, length(iter))
    for (i, params) in enumerate(iter)
        # Unfold
        kmetro, αmetro = params
        # Monte Carlo
        vs = pmap(n -> mobility_mean_velocity(D_mobility, D_day, mobility_df;
            metro_mean_velocity, traffic_mean_velocity,
            kmetro, ktraffic, αmetro, αtraffic), 1:N)
        # Save results
        result[:, i] .= kmetro, αmetro, mean(vs), std(vs)
    end

    # Save index and adjacency matrix
    jldsave(output; result)
    # Final time
    final_time = now()
    println("• Run started ", init_time, " and finished ", final_time)

    nothing
end

main()