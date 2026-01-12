module DelaunayBowyerWatson

using LinearAlgebra: det # für det()
using ..NewTypes

export insert_point!

"""
Hilfsfunktion. Gibt true zurück, wenn der Punkt P im Außenkreis des Dreicks t ist.
Siehe Aufgabenstellung.
"""
function _in_umkreis(t::Dreieck, P::Punkt)::Bool
    a,b,c = getPoints(t)
    A = [a.x a.y (a.x^2 + a.y^2) 1
        b.x b.y (b.x^2 + b.y^2) 1
        c.x c.y (c.x^2 + c.y^2) 1
        P.x P.y (P.x^2 + P.y^2) 1]
    return det(A) > 0
end

"""
Hilfsfunktion. Überprüft ob eine neue Instanz eines Punkts bereits (im Sinne von gleichen Koordinaten) in einer Punktemenge enthalten ist.
Sonst könnte man unendlich oft eine neue Instanz des gleichen Punkts in die Triangulierung einfügen.
"""
function _point_in_set(s::Set{Punkt}, p::Punkt)::Bool
    for pt in s
        if pt == p
            return true
        end
    end
    return false
end

"""
Gibt die Kanten in einem Vektor von Kanten zurück, die genau ein Mal vorkamen.
Das dient zum finden der äußeren Kanten eines "Lochs" an der Stelle der Triangulierung,
in der Dreiecke den Punkt P im Außenkreis enthalten.
"""
function _get_unique_edges(s::Vector{Kante})::Set{Kante}
    counts = Dict{Kante, Int}()
    for e in s
        counts[e] = get(counts, e, 0) + 1
    end
    return Set([e for (e, count) in counts if count == 1])
end

"""
Hilfsfunktion. Überprüft, ob ein Punkt auf einer Kante des Bounding-Dreicks liegt.
Nutzt die Funktion clockwise_colinear zum Überpüfen der Kolinearität.
"""
function _is_edge_point(p::Punkt, D::Delaunay)::Bool
    if p ∈ getPoints(D.bounding_triangle)
        return true
    else
        edge_point = false
        bound1 = D.bounding_triangle.e1
        bound2 = D.bounding_triangle.e2
        bound3 = D.bounding_triangle.e3
        for bound in [bound1, bound2, bound3]
            x_min = min(bound.origin.x, bound.target.x)
            x_max = max(bound.origin.x, bound.target.x)
            y_min = min(bound.origin.y, bound.target.y)
            y_max = max(bound.origin.y, bound.target.y)
            if clockwise_colinear(p, bound.origin, bound.target) !== (true, true)
                continue
            else
                edge_point = (x_min <= p.x <= x_max) && (y_min <= p.y <= y_max)
                if edge_point
                    break
                end
            end
        end
        return edge_point
    end
end

"""
    insert_point!(p::Punkt, D::Delaunay)

Fügt den Punkt p in die Triangulierung ein, falls er valide (nicht außerhalb des Spielfelds,
nicht schon ein Mal gesetzt) ist.

Zusätzlich werden alle Punkt-Kante-Dreiecks-Beziehungen aktualisiert und die Mengen
D.triangles und D.points aktualisiert und bereinigt.

Falls neu entstandene Dreiecke auf einer Kante des Bounding-Dreicks liegen, werden sie als external markiert.

Nutzt den Bowyer-Watson-Algorithmus. Orientiert sich an dieser JavaScript Variante:
https://www.gorillasun.de/blog/bowyer-watson-algorithm-for-delaunay-triangulation/

LAUFZEIT: Siehe Kommentare. Bis auf bereinigen der Kanten O(n). Letzte For-Schleife ist O(n^2)
Anzahl Dreiecke ist linear in Anzahl der Punkte: O(t) ∈ O(n)

# Beispiele
```julia-repl
julia> pts = [Punkt(5,7), Punkt(8,9), Punkt(2,2)];
julia> D = Delaunay(10);
julia> for pt in pts
        insert_point!(pt, D)
       end
julia> D.triangles
Set{Dreieck} with 7 elements:
   (8.0, 9.0) (5.0, 7.0) (2.0, 2.0)…
   (-15.0, 0.0) (2.0, 2.0) (5.0, 7.0)…
   (25.0, 0.0) (5.0, 40.0) (8.0, 9.0)…
   (8.0, 9.0) (2.0, 2.0) (25.0, 0.0)…
   (5.0, 7.0) (5.0, 40.0) (-15.0, 0.0)…
   (5.0, 40.0) (5.0, 7.0) (8.0, 9.0)…
   (-15.0, 0.0) (25.0, 0.0) (2.0, 2.0)…
```
"""
function insert_point!(p::Punkt, D::Delaunay)
    if (p.x > D.n) || (p.x < 0) || (p.y > D.n) || (p.y < 0) # Außerhalb des Spielfelds
        println("Out of Bounds!")
        # O(1) Intervallgrenzen checken

    elseif _point_in_set(D.points, p) # Identisch mit einem Punkt, der schon ein Mal gesetzt wurde
        println("Duplicate Point!")
        # O(n) muss im Worst-Case jeden Punkt anschauen

    else
        affected_tris = filter(t -> _in_umkreis(t, p), D.triangles) # Alle Dreiecke, dessen Außenkreis p enthält
        # O(t) Umkreistest für alle Dreiecke (t = Anzahl Dreiecke ∈ O(n))

        setdiff!(D.triangles, affected_tris) # Entfernt diese Dreiecke aus der Triangulierung: erstellt ein "Loch" um p
        # O(t) alle betroffenen Dreiecke (können alle sein)

        affected_edges = [e for tri in affected_tris for e in (tri.e1, tri.e2, tri.e3)] # Findet alle (doppelten) Dreieckskanten
        # O(t) alle betroffenen Dreieckskanten

        unique_edges = _get_unique_edges(affected_edges) # Findet die Kanten, die genau ein Mal vorkommen: äußere Kanten des "Lochs"
        # O(t) alle betroffenen Dreieckskanten

        p_on_edge = _is_edge_point(p, D)
        # O(1)

        for e in unique_edges # Alle zum "Loch" äußeren Kanten werden mit p verbunden, sodass neue Dreiecke entstehen
            a = e.origin
            b = e.target
            count = _is_edge_point(a, D) + _is_edge_point(b, D) + p_on_edge # Anzahl Punkte, die auf den Bounding-Kanten liegen
            is_external = count >= 2 # liegen mindestens zwei außen, ist das Dreieck auf der Bounding-Kante -> markiert ggf. das Dreieck als äußeres Dreieck
            # O(1)

            if clockwise_colinear(a,b,p)[2] == false # falls hier true steht, sind a,b,p kolinear und wir würden ein "degeniertes" Dreieck erstellen
                bp = Kante(b, p) # findet eine alte Kante bp oder erstellt eine neue
                pa = Kante(p, a)
                T = Dreieck(e, bp, pa, ext=is_external) # neues Dreieck
                push!(D.triangles, T) # neues Dreieck wird in die Triangulierung gefügt
                # O(1)

            end
        end
        # O(t) * (O(1) + O(1)) -> O(t)

        valid_edges = Set{Kante}() # merkt sich alle Kanten in der neuen Triangulierung
        for t in D.triangles # löscht alte Dreiecke aus den Mengen von Kanten der aktuellen Dreiecke
            intersect!(t.e1.tri, D.triangles) 
            intersect!(t.e2.tri, D.triangles)
            intersect!(t.e3.tri, D.triangles)
            # intersect! soll Laufzeit O(kleinere Menge) haben also hier O(1), da jede Kante max. 2 Dreiecke haben kann

            push!(valid_edges, t.e1)
            push!(valid_edges, t.e2)
            push!(valid_edges, t.e3)
            # O(1)
        end
        # O(t)*(O(1) + O(1)) -> O(t)

        push!(D.points, p) # fügt den neuen Punkt in die Punktmenge

        for pt in D.points
            intersect!(pt.adj, valid_edges) # löscht alte Kanten aus den Mengen von Punkten der Triangulierung
            # O(t)
        end
        # O(n)*O(t)

    end
end

end # Module end