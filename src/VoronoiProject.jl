module VoronoiProject
# HAUPTDATEI zum Sammeln der Module
#=
    ggf. in die Konsole tippen:
    ] pkg activate .
    using VoronoiProject
    using Revise
=#

# Module:
include("NewTypes.jl")
include("DelaunayBowyerWatson.jl")
include("CreateVoronoi.jl")
include("RandomDiagram.jl")

using .NewTypes
using .DelaunayBowyerWatson
using .CreateVoronoi
using .RandomDiagram

# Exports ermöglichen das direkte Aufrufen der Funktionen z.B. "Punkt()" anstatt "VoronoiProject.Types.Punkt()"
# Exports:
export Punkt, round_point, Kante, Dreieck, clockwise_colinear, getPoints, Delaunay, Polygon # aus NewTypes
export insert_point!, colinear_to_existing # aus DelaunayBowyerWatson
export voronoi # aus CreateVoronoi
export execute_visuals, execute_tests, greet
export random_voronoi, display_voronoi

greet() = println("hello!") # zum Testen, ob Zugriff auf Hauptdatei funktioniert
execute_visuals() = include(joinpath(@__DIR__, "Visiuals.jl"))
execute_tests() = include("test/runtests.jl") # schneller als pkg test

end # Module end