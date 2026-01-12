module NewTypes

export Punkt, round_point, Kante, Dreieck, clockwise_colinear, getPoints, Delaunay, Polygon

############### Punkt ###############
abstract type AbstractKante end
struct Punkt
    x::Float64
    y::Float64
    adj::Union{Set{AbstractKante}, Nothing}
    player::Union{String, Nothing} # soll nur einen Wert !=nothing haben, falls der Punkt vom Spieler gesetzt wurde.
end

# Konstruktor für Punkte ohne Kantenbeziehungen & ohne Spieler
Punkt(x::Real,y::Real) = Punkt(x, y, Set{AbstractKante}(), nothing) 

# Konstruktor für Punkte ohne Kantenbeziehungen
Punkt(x::Real,y::Real, s::String) = Punkt(x, y, Set{AbstractKante}(), s) 

# zum schönen Anzeigen der Punkte
function Base.show(io::IO, P::Punkt)
    if isnothing(P.adj)
        print(io,"Punkt($(P.x), $(P.y))")
    elseif isempty(P.adj)
        print(io,"Punkt($(P.x), $(P.y))")
    elseif P.player == "Blau"
        println(io,"Blauer Punkt ($(P.x), $(P.y)) mit $(length(P.adj)) angrenzenden Kanten")
    elseif P.player == "Rot"
        println(io,"Roter Punkt ($(P.x), $(P.y)) mit $(length(P.adj)) angrenzenden Kanten")
    else
        print(io,"Punkt ($(P.x), $(P.y)) mit $(length(P.adj)) angrenzenden Kanten")
    end
end

"""
Rundet die x- und y-Koordinaten eines Punkts auf 0 und n, falls sie in der Umgebung 10^-10 davon liegen.
Gibt einen neuen, gerundeten Punkt zurück.
"""
function round_point(p::Punkt, n::Int)::Punkt
    x = p.x
    y = p.y
    if isapprox(x, n; atol=1e-10) x = n end
    if isapprox(y, n; atol=1e-10) y = n end
    if isapprox(x, 0; atol=1e-10) x = 0 end
    if isapprox(y, 0; atol=1e-10) y = 0 end
    return Punkt(x,y, p.adj, p.player)
end

# Punkte sind gleich, wenn die Koordinaten gleich sind
Base.:(==)(a::Punkt, b::Punkt) = (a.x == b.x && a.y == b.y) 

# Punkte können sortiert werden (nur für Hashing der Kanten wichtig)
Base.min(p1::Punkt, p2::Punkt) = min((p1.x, p1.y),(p2.x, p2.y))
Base.max(p1::Punkt, p2::Punkt) = max((p1.x, p1.y),(p2.x, p2.y))

############### Kante ###############
abstract type AbstractDreieck end
struct Kante <: AbstractKante
    origin::Punkt
    target::Punkt
    tri::Set{AbstractDreieck}
end

# Kanten sind gleich, wenn sie die gleichen Endpunkte haben (egal in welcher Reihenfolge)
Base.:(==)(v::Kante, w::Kante) = (v.origin == w.origin && v.target == w.target) || (v.origin == w.target && v.target == w.origin)

# zum schönen Anzeigen der Kanten
function Base.show(io::IO, v::Kante)
    if isnothing(v.tri)
        print(io::IO, "Kante ($(v.origin.x), $(v.origin.y)) -> ($(v.target.x), $(v.target.y))")
    else
        print(io::IO, "Kante ($(v.origin.x), $(v.origin.y)) -> ($(v.target.x), $(v.target.y)) mit $(length(v.tri)) angrenzenden Dreiecken")
    end
end

"""
Überprüft a.adj und b.adj, ob es schon eine Kante zwischen den Punkten gibt.
Falls ja, wird keine neue Kante erstellt und die alte Kante zurückgegeben.
Andernfalls wird eine neue erstellt und zu a.adj & b.adj hinzugefügt.
"""
function Kante(a::Punkt, b::Punkt)
    k = Kante(a,b, Set{AbstractDreieck}()) # erstelle eine neue Kante (die nur wenn sie wirklich neu ist gebraucht wird)
    for e in a.adj
        if (e.origin == a && e.target == b) || (e.origin == b && e.target == a)
            return e # falls es schon eine Kante mit diesen Endpunkten gibt, gib die zurück
        end
    end
    push!(a.adj, k) # falls die Kante echt neu ist, aktualisiere die P.adj
    push!(b.adj, k)
    return k
end

# Kanten mit gleichen Endpunkten sollen von Hash-Operationen wie Set() nur einmal instanziert werden
function Base.hash(e::Kante, h::UInt)
    return hash((min(e.origin, e.target), max(e.origin, e.target)), h)
end

"""
Hilfsfunktion für Mittelwert einer Kante.
Gibt den Mittelpunkt als Punkt zurück.
"""
function _midpoint(e::Kante)::Punkt
    x1 = e.origin.x
    y1 = e.origin.y
    x2 = e.target.x
    y2 = e.target.y
    return Punkt((x1+x2)/2,(y1+y2)/2)
end

"""
Hilfsfunktion, um die Steigung einer Kante zu finden.
Gibt nothing zurück, falls die x-Koordinaten von Anfangs- und Endpunkt gleich sind.
"""
function _slope(e::Kante)::Union{Float64, Nothing}
    x1 = e.origin.x
    y1 = e.origin.y
    x2 = e.target.x
    y2 = e.target.y
    if x1 == x2
        return nothing
    else 
        return (y2-y1)/(x2-x1)
    end
end

"""
Hilfsfunktion um die Steigung der Mittelsenkrechte einer Kante zu finden.
"""
function _perp_bi_slope(e::Kante)::Union{Float64, Nothing}
    m = _slope(e)
    if isnothing(m)
        return 0
    elseif m == 0
        return nothing
    else 
        return -1/m
    end
end

"""
Hilfsfunktion. Berechnet den Mittelpunkt des Außenkreises des Dreiecks, das durch zwei Kanten bestimmt ist.
"""
function _center_circle_tri(e1::Kante, e2::Kante)::Punkt
    mid_e1 = _midpoint(e1)
    mid_e2 = _midpoint(e2)
    m1 = _perp_bi_slope(e1)
    m2 = _perp_bi_slope(e2)
    if m1 === nothing
        x = mid_e1.x 
        y = m2*(x-mid_e2.x)+mid_e2.y
    elseif m2 === nothing
        x = mid_e2.x 
        y = m1*(x-mid_e1.x)+mid_e1.y
    else
        x = ((m1 * mid_e1.x - mid_e1.y) - (m2 * mid_e2.x - mid_e2.y)) / (m1 - m2)
        y = m1 * (x - mid_e1.x) + mid_e1.y
    end
    return Punkt(x, y, nothing, nothing)
end

############### Dreieck ###############
struct Dreieck <: AbstractDreieck
    e1::Kante
    e2::Kante
    e3::Kante
    circumcenter::Union{Punkt, Nothing}
    external::Bool

    """
    Konstruktor für neue Dreiecke aus drei Kanten. Als Default-Wert ist es kein äußeres Dreieck.
    Berechnet direkt den Mittelpunkt des Außenkreises. 
    Aktualisiert die Inzidenzlisten der beteiligten Kanten mit dem neuen Dreieck.
    """
    function Dreieck(e1::Kante, e2::Kante, e3::Kante; ext=false) # Konstruktor für neue Dreiecke
        circumcenter_pt = _center_circle_tri(e1, e2)
        T = new(e1, e2, e3, circumcenter_pt, ext)
        for e in [e1, e2, e3]
            push!(e.tri, T) # aktualisiert die Inzidenz-Mengen aller Kanten im Dreieck
        end
        return T
    end
end

"""
Konstruktor für neue Dreiecke nur aus Punkten (sollte nur für 3 neue Punkte verwendet werden, z.B. fürs bounding_triangle).
"""
function Dreieck(p1::Punkt, p2::Punkt, p3::Punkt; ext=false)
    e1 = Kante(p1, p2)
    e2 = Kante(p2, p3)
    e3 = Kante(p3, p1)
    return Dreieck(e1, e2, e3, ext=ext)
end

"""
Gibt zurück
(true, false) falls 3 Punkte gegen den Uhrzeigersinn geordnet sind
(false, false) falls im Uhrzeigersinn
(true, true) falls alle auf einer Geraden liegen (kolinear)
Das funktioniert nur für 3 Punkte, für mehrere muss ein anderer Algorithmus her (siehe CreateVoronoi).
"""
function clockwise_colinear(a::Punkt, b::Punkt, c::Punkt)::Tuple{Bool, Bool}
    slope = ((b.y - a.y)*(c.x - b.x)) - ((b.x - a.x)*(c.y - b.y))
    if slope == 0
        return (true, true)
    elseif slope > 0
        return (false, false)
    else
        return (true, false)
    end
end

"""
Hilfsfunktion. Ordnet drei Punkte gegen den Uhrzeigersinn.
"""
function _order_points(a::Punkt, b::Punkt, c::Punkt)::Tuple{Punkt, Punkt, Punkt}
    orientation = clockwise_colinear(a,b,c)
    if orientation[1] == true
        return (a,b,c)
    else
        return (c,b,a)
    end
end

"""
Findet die Eckpunkte eines Dreiecks t und gibt sie geordnet als Tupel zurück.
Das wird gebraucht, da wir vorab die Sortierung der Punkte nicht kennen.
"""
function getPoints(t::Dreieck)::Tuple{Punkt, Punkt, Punkt}
    points = [t.e1.origin, t.e2.origin, t.e3.origin, t.e1.target, t.e2.target, t.e3.target]
    unique_points = Punkt[]
    for p in points
        if all(q -> !(p == q), unique_points) # falls der Punkt nicht doppelt ist
            push!(unique_points, p)
        end
    end

    if length(unique_points) != 3
        error("Degeneriertes Dreieck: Enthält $(length(unique_points)) Punkte")
    end

    return _order_points(unique_points[1], unique_points[2], unique_points[3])
end

# zum schönen Anzeigen von Dreiecken
function Base.show(io::IO, t::Dreieck)
    print(io, "\nDreieck mit Punkten:")
    for pt in getPoints(t)
        print(" ($(pt.x), $(pt.y))")
    end
end

############### Delaunay ###############
struct Delaunay
    triangles::Set{Dreieck}
    points::Set{Punkt}
    bounding_triangle::Dreieck
    n::Int
end

"""
Erstellt eine Delaunay-Triangulierung für ein Spielfeld der Größe n.
Sie enthält zu Anfang nur das Bounding-Dreieck.
"""
function Delaunay(n::Int)
    p1 = Punkt(n/2, 6n)
    p2 = Punkt(-7n/2, -2n)
    p3 = Punkt(9n/2, -2n)

    bounding_triangle = Dreieck(p1, p2, p3, ext=true)
    Delaunay(Set{Dreieck}([Dreieck(p1, p2, p3, ext=true)]), Set{Punkt}([p1,p2,p3]), bounding_triangle, n)
end
############### Voronoi ###############
"""
Hilfsfunktion. Sortiert einen Vektor an Punkten gegen den Uhrzeigersinn.
Der Mittelpunkt wird bestimmt und die Punkte nach ihrem Winkel zum Mittelpunkt geordnet.
https://pavcreations.com/clockwise-and-counterclockwise-sorting-of-coordinates/
"""
function _polygon_clockwise_sort(v::Vector{Punkt})::Vector{Punkt}
    s = length(v)
    x = 0.0
    y = 0.0
    for p in v
        x += p.x 
        y += p.y 
    end
    center_point = Punkt(x/s,y/s,nothing,nothing)
    sorted_polygon = reverse(sort(v, by = p -> atan(p.y - center_point.y, p.x - center_point.x)))
    return sorted_polygon
end

struct Polygon
    points::Vector{Punkt}
    Polygon(v::Vector{Punkt}) = new(_polygon_clockwise_sort(v)) # Ein Polygon wird direkt immmer sortiert.
end

# Polygone sind gleich, wenn sie die gleichen Punkte enthalten.
function Base.:(==)(P::Polygon, Q::Polygon)
    if length(P.points) !== length(Q.points)
        return false
    else
        for i = 1:length(P.points)
            if P.points[i] !== Q.points[i]
                return false
            end
        end
        return true
    end
end

# Polygone haben fließende Indizierung: ["a", "b", "c"][4] == "a"
function Base.getindex(poly::Polygon, i::Int)
    l = length(poly.points)
    @assert l>0
    return poly.points[mod1(i, l)]
end

end # Module end