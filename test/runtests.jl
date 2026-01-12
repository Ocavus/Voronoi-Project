using Test
using VoronoiProject
using VoronoiProject.NewTypes: _slope, _midpoint, _center_circle_tri, getPoints, clockwise_colinear
using VoronoiProject.CreateVoronoi: _adjacent_triangle_finder, _perp_bisector, _voronoi_cell_point, _clip_poly, voronoi
#=
    zum testen in die Konsole tippen:
    ] test
=#

@testset "Types" begin
    @testset "Punkt" begin
        # funktioniert Runden?
        @test round_point(Punkt(10^(-11), 0), 10).x == 0 
        @test round_point(Punkt(0, 10+10^(-11)), 10).y == 10.0 
        # funktioniert Gleicheit (und Conversion zu Float)?
        @test Punkt(1,1) == Punkt(1.0,1.0)
    end

    @testset "Kante" begin
        a = Punkt(1,1)
        b = Punkt(1,3)
        c = Punkt(3,1)
        # funktioniert Kante() bei neuen/schon existierenden Kanten
        e1 = Kante(a,b)
        @test e1.origin == a
        @test e1.target == b
        e2 = Kante(b,c)
        @test e2.origin == b 
        @test e2.target == c
        # funktioniert P.adj?
        @test e1 in a.adj 
        @test e1 in b.adj
        # funktioniert Midpoint?
        @test _midpoint(e1) == Punkt(1.0, 2.0, nothing, nothing)
        # funktioniert slope
        @test _slope(e1) === nothing
        @test _slope(e2) == -1
        # funktioniert _center_circle_tri
        @test _center_circle_tri(e1, e2) == Punkt(2,2, nothing, nothing)

    end

    @testset "Dreieck" begin
        a = Punkt(1,1)
        b = Punkt(1,3)
        c = Punkt(3,1)
        ab = Kante(a,b)
        bc = Kante(b,c)
        ca = Kante(c,a)
        t = Dreieck(ab,bc,ca)
        # funktioniert e.tri Inzidenzliste?´
        @test t in ab.tri
        @test t in bc.tri
        @test t in ca.tri
        # funktioniert getPoints
        @test getPoints(t) == (c,b,a)
        # funktioniert clockwise_colinear?
        @test clockwise_colinear(a, b, c) == (false, false)
        @test clockwise_colinear(a, c, b) == (true, false)

    end

    @testset "Polygon" begin
        p1 = Punkt(1, 1)
        p2 = Punkt(3, 3)
        p3 = Punkt(1, 3)
        p4 = Punkt(3, 1)
        points = [p1, p2, p3, p4]
        polygon = Polygon(points)
        # funktioniert sortieren der Punkte?
        @test polygon.points[1] == p3
        @test polygon.points[2] == p2
        @test polygon.points[3] == p4
        @test polygon.points[4] == p1
        # funktioniert fließende Indizierung?
        @test polygon[5] == polygon[1]
        @test polygon[0] == polygon[4]  
        @test polygon[-1] == polygon[3]  
    end
end

@testset "DelaunayBowyerWatson" begin
    @testset "Umkreis-Test" begin
        a1 = Punkt(0,0)
        b1 = Punkt(4,0)
        c1 = Punkt(0,3)
        t1 = Dreieck(a1,b1,c1)
        d11 = Punkt(1,1)
        d12 = Punkt(4,4)
        @test VoronoiProject.DelaunayBowyerWatson._in_umkreis(t1,d11) == true
        @test VoronoiProject.DelaunayBowyerWatson._in_umkreis(t1,d12) == false
    end

    @testset "Insert_Point" begin
        D1 = Delaunay(10)
        pts = [(5,7), (4,4), (4,6), (3,9), (8,9), (0,9), (2,7), (2,2), (0,0), (4,4)] # ein Punkt soll nicht hinzugefügt werden.
        for pt in pts
            insert_point!(Punkt(pt[1], pt[2]), D1)
        end
        @test length(D1.triangles) == 19

        D2 = Delaunay(10)
        x = 10*rand(100)
        y = 10*rand(100)
        for k = 1:100
            insert_point!(Punkt(x[k],y[k]), D2)
        end
        @test length(D2.triangles) == 201
    end
end

@testset "CreateVoronoi" begin
    D1 = Delaunay(10)
    pts = [(1,1), (5,5), (9,9), (4,7)]
    a = Punkt(1,1)
    b = Punkt(1,3)
    c = Punkt(3,1)
    ab = Kante(a,b)
    bc = Kante(b,c)
    ca = Kante(c,a)
    t = Dreieck(ab,bc,ca)
    polygon = Polygon([Punkt(5,-2), Punkt(8,5), Punkt(5,12), Punkt(2,5)])
    for pt in pts
        insert_point!(Punkt(pt[1], pt[2]), D1)
    end
    # funktioniert _adjacent_triangle_finder
    adj_tri = _adjacent_triangle_finder(a)
    @test t in adj_tri
    @test length(adj_tri) == 1

    # funktioniert _perp_bisector
    @test _perp_bisector(ab,t) == [1.0, -0.0]

    # funktioniert _voronoi_cell_point
    point_voronoi = _voronoi_cell_point(Punkt(pts[1]...), D1)
    @test point_voronoi isa Vector{Punkt}
    # funktioniert edge clipping
    clipped = _clip_poly(polygon, D1)
    @test clipped isa Polygon
    @test all(p -> 0 <= p.x <= 10 && 0 <= p.y <= 10, clipped.points)

    # funktioniert Voronoi mit neuem Dictionary
    voronoi_dict = voronoi(D1)
    @test length(voronoi_dict) == length(pts)
    @test all(cell isa Polygon for cell in values(voronoi_dict))
    # funktioniert aktualisieren von Dictionary mit voronoi
    new_voronoi_dict = voronoi(D1)
    @test keys(new_voronoi_dict) == keys(voronoi_dict)
    # passiert nichts wenn man wiederholt voronoi ausführt, ohne Punkte zu ändern
    before_points = deepcopy(D1.points)
    voronoi(D1)
    after_points = D1.points
    @test Set((p.x, p.y) for p in before_points) == Set((p.x, p.y) for p in after_points)
end