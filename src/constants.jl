# Local MexicoCityMetro path
const PACKAGE_DIRECTORY = pkgdir(MexicoCityMetro)

# Metro stations and lines .kml files
# https://datos.cdmx.gob.mx/dataset/lineas-y-estaciones-del-metro
const METRO_STATIONS_FILE = joinpath(PACKAGE_DIRECTORY, "data", "STC_Metro_estaciones.kml")
const METRO_LINES_FILE = joinpath(PACKAGE_DIRECTORY, "data", "STC_Metro_lineas.kml")
# Official subway lines colors
const METRO_LINES_COLORS = [colorant"#F04E98", colorant"#005EB8", colorant"#AF9800",
    colorant"#6BBBAE", colorant"#FFD100", colorant"#DA291C",
    colorant"#E87722", colorant"#009A44", colorant"#512F2E",
    colorant"#981D97", colorant"#B1B3B3", colorant"#B0A32A"]

# AGEB: Área geoestadística básica

# AGEBs .csv file
# https://osf.io/gwq6u/
const AGEBS_FILE = joinpath(PACKAGE_DIRECTORY, "data", "agebs_ZMVM.csv")

# Daily origin-destiny network files root
const DAY_FILE_ROOT = "od_cvegeo_09_01_"

# Global parameters
const METRO_MEAN_VELOCITY = 600 # m/min (36 km/h)
const TRAFFIC_MEAN_VELOCITY = 300 # m/min (18 km/h)
const MAXIMUM_DISTANCE_TO_METRO = 10_000 # m (10 km)