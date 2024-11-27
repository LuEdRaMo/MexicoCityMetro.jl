# Local MexicoCityMetro path
const PACKAGE_DIRECTORY = pkgdir(MexicoCityMetro)

# Metro stations and lines .kml files
# https://datos.cdmx.gob.mx/dataset/lineas-y-estaciones-del-metro
const METRO_STATIONS_FILE = joinpath(PACKAGE_DIRECTORY, "data", "STC_Metro_estaciones.kml")
const METRO_LINES_FILE = joinpath(PACKAGE_DIRECTORY, "data", "STC_Metro_lineas.kml")
# Official subway lines colors
const METRO_LINES_COLORS = Dict(
    "1" => colorant"#F04E98",
    "2" => colorant"#005EB8",
    "3" => colorant"#AF9800",
    "4" => colorant"#6BBBAE",
    "5" => colorant"#FFD100",
    "6" => colorant"#DA291C",
    "7" => colorant"#E87722",
    "8" => colorant"#009A44",
    "9" => colorant"#512F2E",
    "A" => colorant"#981D97",
    "B" => colorant"#B1B3B3",
    "12" => colorant"#B0A32A"
)

# AGEB: Área geoestadística básica

# AGEBs .csv file
# https://osf.io/gwq6u/
const AGEBS_FILE = joinpath(PACKAGE_DIRECTORY, "data", "agebs_ZMVM.csv")

# Daily origin-destiny network files root
const DAY_FILE_ROOT = "od_cvegeo_09_01_"

# Global parameters
const METRO_MEAN_VELOCITY = 600.0 # m/min (36 km/h)
const TRAFFIC_MEAN_VELOCITY = 300.0 # m/min (18 km/h)
const MAXIMUM_DISTANCE_TO_METRO = 10_000 # m (10 km)