module CreateVoronoi
# Zum Umwandeln der Dreiecke aus dem Delaunay struct in ein Voronoi-Diagramm (Aufgabe 4)

using ..NewTypes
using ..DelaunayBowyerWatson
using LinearAlgebra: norm, dot

export voronoi

"""
Hilfsfunktion. Findet alle angrenzenden Dreiecke für einen gegebenen Punkt.
Durchsucht die Inzidenzlisten der zum Punkt inzidenten Kanten und speichert sie in einer Menge.
"""
function _adjacent_triangle_finder(p::Punkt)::Set{Dreieck}
    adj_tri = Set{Dreieck}()
    for e in p.adj
        for t in e.tri
            push!(adj_tri, t::Dreieck)
        end
    end
    return adj_tri
end

"""
Berechnet einen Vektor, dessen Richtung vom Dreiecks-Mittelpunkt zur Kante e aus dem Dreieck raus zeigt.
"""
function _perp_bisector(e::Kante, t::Dreieck)::Vector{Float64}
    e1 = e.origin
    e2 = e.target
    c = t.circumcenter
    # Vektor senkrecht zur Kante
    v = [-(e2.y - e1.y), (e2.x -e1.x)]
    # Normieren
    v = v ./norm(v)

    # Kantenmittelpunkt
    M = [(e1.x + e2.x)/2, (e1.y + e2.y)/2]
    # Vektor vom Dreiecksmittelpunkt zum Kantenmittelpunkt
    w = [c.x - M[1], c.y - M[2]]
    dotprod = dot(w,v)

    if dotprod < 0
        v = -v
    end
    return v
end

"""
Hilfsfunktion. Berechnet den Endpunkt eines skalierten Vektors aus _perp_bisector().
Dabei wird die Kante gegenüber vom Punkt p im Dreieck t gewählt.
Der Endpunkt liegt gesichert außerhalb der Delaunay-Spielfeldgröße.
Der Punkt dient zur korrekten Darstellung von Voronoi-Zellen, die am Rand des Bounding-Dreiecks liegen.
Offene Zellen werden aus dem Spielfeld raus verlängert.
"""
function _get_extended_pt(p::Punkt, t::Dreieck, D::Delaunay)::Punkt
    # Finde die Kante, die p gegenüber liegt
    opposing = nothing
    for e in [t.e1, t.e2, t.e3]
        if !(p∈(e.origin, e.target))
            opposing = e
            break
        end
    end
    v = _perp_bisector(opposing, t)
    c = t.circumcenter
    skalar = (2*D.n)/sqrt(2)
    return Punkt(c.x + v[1]*skalar, c.y + v[2]*skalar)
end

"""
Hilfsfunktion. Findet die angrenzenden Dreiecke eines Punkts, betrachtet die Mittelpunkte ihrer Außenkreise und speichert sie im Vektor.
Liegt ein Dreieck auf der Kante des Bounding-Dreiecks, wird ein mit _get_extended_pt() berechneter extra-Punkt hinzugefügt.
"""
function _voronoi_cell_point(p::Punkt, D::Delaunay)::Vector{Punkt}
    adj_tri = _adjacent_triangle_finder(p)
    # O(t) im Worst-Case

    polygon = Punkt[]
    
    for t in adj_tri
        if t.external
            extended_pt = _get_extended_pt(p, t, D)
            # O(1)

            push!(polygon, t.circumcenter)
            push!(polygon, extended_pt)
            # O(1)
        else
            push!(polygon, t.circumcenter)
            # O(1)
        end
    end
    # O(t)*(O(1)+O(1)) -> O(t)
    return polygon
end

"""
Hilfsfunktion für Edge-Clipping. Berechnet den Schnittpunkt von zwei Geraden, die durch Punkte gegeben sind.
Gibt nothing zurück, falls sie parallel sind.
"""
function _intersection(p1::Punkt, p2::Punkt, q1::Punkt, q2::Punkt)::Union{Nothing, Punkt}
    dx1 = p2.x - p1.x
    dy1 = p2.y - p1.y
    dx2 = q2.x - q1.x
    dy2 = q2.y - q1.y
    s2 = dx1*dy2 - dy1*dx2

    if iszero(s2)
        return nothing
    end

    dx = q1.x - p1.x
    dy = q1.y - p1.y
    s1 = dx*dy2 - dy*dx2
    s= s1/s2
    return Punkt(p1.x + s*dx1, p1.y + s*dy1)
end

"""
Hilfsfunktion für Polygon-Clipping. Clipped ein Polygon gegen eine Kante und gibt das neue Polygon zurück.
Durchläuft die Punkte des Polygons und berechnet einen Schnittpunkt mit der Kante, falls es ein Punkte-Pärchen
findet, von dem ein Punkt links und einer rechts von der Kante liegt. 
https://www.geeksforgeeks.org/dsa/polygon-clipping-sutherland-hodgman-algorithm/
"""
function _edge_clip(poly::Polygon, e::Kante)::Polygon
    clipped = Vector{Punkt}()
    e1 = e.origin
    e2 = e.target
    l = length(poly.points)

    for i=1:l
        p1 = poly[i]
        p2 = poly[i+1]
        p1_inside = ((e2.x - e1.x)*(p1.y - e1.y) - (e2.y - e1.y)*(p1.x - e1.x)) < 0
        p2_inside = ((e2.x - e1.x)*(p2.y - e1.y) - (e2.y - e1.y)*(p2.x - e1.x)) < 0

        # Fall 1: Beide Punkte sind im Quadrat
        if p1_inside && p2_inside
            push!(clipped, p2)
        # Fall 2: Nur der erste Punkt liegt außerhalb des Quadrats
        elseif !p1_inside && p2_inside
            intersection_pt = _intersection(p1, p2, e1, e2)
            push!(clipped, intersection_pt)
            push!(clipped, p2)
        # Fall 3: Nur der zweite Punkt liegt außerhalb des Quadrats
        elseif  p1_inside && !p2_inside
            intersection_pt = _intersection(p1, p2, e1, e2)
            push!(clipped, intersection_pt)
        # Fall 4: Beide Punkten liegen außerhalb des Quadrats
        else
            continue
        end
    end
    return Polygon(clipped)
end

"""
Hilfsfunktion. Clipped ein Polygon gegen die Spielfeldgrenzen. Iteriert über jede Kante des Spielfelds
und wendet _edge_clip() an.
https://www.geeksforgeeks.org/dsa/polygon-clipping-sutherland-hodgman-algorithm/
"""
function _clip_poly(poly::Polygon, D::Delaunay)::Polygon
    n = D.n
    A = Punkt(0,0)
    B = Punkt(0,n)
    C = Punkt(n,n)
    D = Punkt(n,0)
    edges = [Kante(A,B), Kante(B,C), Kante(C,D), Kante(D,A)]
    for edge in edges
        poly = _edge_clip(poly, edge)
    end
    return poly
end

"""
Hilfsfunktion. Rundet die Punkte eines Polygons gegen 0 und n mittels round_point.
"""
function _round_poly(poly::Polygon, D::Delaunay)::Polygon
    n = (D.n)
    points = poly.points
    for i = 1:length(points)
        points[i] = round_point(points[i], n)
    end
    return Polygon(points)
end

"""
    voronoi(D::Delaunay, V=Dict{Punkt, Polygon}())::Dict{Punkt, Polygon}

Berechnet das Voronoi-Diagramm zur Delaunay-Triangulierung D.
Gibt ein Dictionary der mittels insert_point!() in D gesetzten Punkte als Keys
und der zugehörigen Voronoi-Zelle als Value zurück.

Als Default-Wert wird ein neues Dictionary V erstellt. Alternativ kann ein bereits existierendes
Voronoi-Dictionary übergeben werden, in dem nur veränderte oder neue Zellen aktualisiert werden.

Zu jedem inneren Punkt werden Voronoi-Zellen erstellt, dann ins innere des Spielfelds geclipped und
zu 0 und n gerundet, damit die auf den Kanten liegenden Punkt sauber sind.

LAUFZEIT: O(t) Operationen für jeden der O(n) Punkte -> O(n^2)

# Beispiel
```julia-repl
julia> pts = [Punkt(5,7, "Blau"), Punkt(8,9, "Rot"), Punkt(2,2, "Blau")];
julia> D = Delaunay(10);
julia> for pt in pts
        insert_point!(pt, D)
       end
julia> V = voronoi(D)
Dict{Punkt, Polygon} with 3 entries:
  Blauer Punkt (2.0, 2.0) mit 4 angrenzenden Kanten => Polygon(Punkt[Punkt(0.0, 6.6000000000000005), Punkt(10.0, 0.5999999999999996), Punkt(10.0, 0.0), Punkt(0.0, 0.0)])
  Roter Punkt (5.0, 7.0) mit 4 angrenzenden Kanten => Polygon(Punkt[Punkt(0.0, 6.6000000000000005), Punkt(0.0, 10.0), Punkt(5.166666666666666, 10.0), Punkt(10.0, 2.749999999999999), Punkt(10.0, 0.5999999999999999)])
  Blauer Punkt (8.0, 9.0) mit 4 angrenzenden Kanten => Polygon(Punkt[Punkt(5.166666666666669, 10.0), Punkt(10.0, 10.0), Punkt(10.0, 2.750000000000001)])
```
"""
function voronoi(D::Delaunay, V=Dict{Punkt, Polygon}())::Dict{Punkt, Polygon}
    bounding_pts = getPoints(D.bounding_triangle)
    # O(1)

    for p in D.points
        if p in bounding_pts
            continue
        end
        cell = Polygon(_voronoi_cell_point(p, D))
        # O(t)

        clipped_cell = _clip_poly(cell, D)
        # O(t) (Polygon besteht aus Dreiecksmittelpunkten, kann also max. O(t) Punkte enthalten)

        rounded_cell = _round_poly(clipped_cell, D)
        # O(t)

        if !haskey(V, p) || V[p] !== rounded_cell
            V[p] = rounded_cell
        end
    end
    # O(n) Punkte * (O(t) + O(t) + O(t)) -> O(n^2)
    return V
end

end # Module end