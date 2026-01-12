module RandomDiagram

using GLMakie
using Colors
using ..NewTypes
using ..DelaunayBowyerWatson
using ..CreateVoronoi

export random_voronoi, display_voronoi
# Das dient nur zum Test und wurde nach und unabhängig von der Visualisierung erstellt!

function random_voronoi(k::Int = 20, groesse::Int = 10)
    println("Diese Datei dient nur zum Test und wurde nach und unabhängig von der Visualisierung erstellt!")
    fig = Figure(resolution = (800, 800))
    ax = fig[1, 1] = Axis(fig;
        aspect = 1,
        limits = ((0, groesse), (0, groesse)),
        title = "Random Voronoi Diagram",
        titlegap = 20, titlesize = 30,
        xgridvisible = false, ygridvisible = false
    )

    D = Delaunay(groesse)
    points = [Punkt(rand() * groesse, rand() * groesse, "") for _ in 1:k]
    for p in points
        insert_point!(p, D)
    end
    V = voronoi(D)
    for poly in values(V)
        draw_colored_polygon(ax, poly)
    end
    scatter!(ax, [Point2f0(p.x, p.y) for p in points]; color = :black, markersize = 8)
    fig
end

function draw_colored_polygon(ax, polygon::Polygon)
    pts = [Point2f0(p.x, p.y) for p in polygon.points]
    push!(pts, pts[1])
    fill_color = RGBA(rand(), rand(), rand(), 0.4)
    poly!(ax, pts[1:end-1]; color = fill_color, strokecolor = :black, strokewidth = 2)
end

function draw_polygon_edges(ax, polygon::Polygon)
    pts = [Point2f0(p.x, p.y) for p in polygon.points]
    push!(pts, pts[1])
    lines!(ax, pts; color = :black, linewidth = 2)
end


function display_voronoi(points::Vector{Punkt}, groesse::Int = 10)
    println("Diese Datei dient nur zum Test und wurde nach und unabhängig von der Visualisierung erstellt!")
    fig = Figure(resolution = (800, 800))
    ax = fig[1, 1] = Axis(fig;
        aspect = 1,
        limits = ((0, groesse), (0, groesse)),
        title = "Random Voronoi Diagram",
        titlegap = 20, titlesize = 30,
        xgridvisible = false, ygridvisible = false
    )
    D = Delaunay(groesse)

    for p in points
        insert_point!(p, D)
    end

    V = voronoi(D)
    for poly in values(V)
        draw_colored_polygon(ax, poly)
    end

    scatter!(ax, [Point2f0(p.x, p.y) for p in points]; color = :black, markersize = 8)

    fig
end

end
