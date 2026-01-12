#include("NewTypes.jl")
#include("CreateVoronoi.jl")
#include("DelaunayBowyerWatson.jl")
using GLMakie
using ..NewTypes
using ..DelaunayBowyerWatson
using ..CreateVoronoi

fig = Figure(resolution = (1840, 1860))

# Initialgröße
startgröße = 10

# Achse
ax = fig[2, 1] = Axis(fig;
    aspect = 1,
    limits = ((0, startgröße), (0, startgröße)),
    title = "Voronoi Madniss",
    titlegap = 48, titlesize = 60,
    xautolimitmargin = (0, 0), xgridwidth = 2, xticklabelsize = 20,
    xticks = 0:1:startgröße, xticksize = 18,
    yautolimitmargin = (0, 0), ygridwidth = 2, yticklabelpad = 14,
    yticklabelsize = 20, yticks = 0:1:startgröße, yticksize = 18
)

# Slider für Spielfeldgröße
gslidergrit = labelslidergrid!(fig,
    ["Spielfeldgröße", "Spiellänge"],
    Ref(LinRange(0:1:40));
    formats = [x -> string(x)],
    labelkw = Dict([(:textsize, 30)]),
    sliderkw = Dict([(:linewidth, 24)]),
    valuekw = Dict([(:textsize, 30)])
)

# Slider für x und y Achsen
pslidergrid = labelslidergrid!(fig,
    ["x-Achse Blau", "y-Achse Blau", "x-Achse Rot", "y-Achse Rot"],
    Ref(LinRange(0:0.01:10));
    formats = [x -> "$(round(x, digits = 2))"],
    labelkw = Dict([(:textsize, 30)]),
    sliderkw = Dict([(:linewidth, 24)]),
    valuekw = Dict([(:textsize, 30)])
)

#Buttons um Punkte zu setzten
labels = ["Blau Setzen", "Rot Setzen"]

buttons = [
    Button(fig, label = l, height = 60, width = 250, textsize = 30)
    for l in labels
]
buttongrid = GridLayout(tellwidth = false)
buttongrid[1, 1] = buttons[1]
buttongrid[1, 2] = buttons[2]


# Startwert setzen
set_close_to!(gslidergrit.sliders[1], startgröße)
set_close_to!(gslidergrit.sliders[2], 10)

# Layout
sl_sublayout = GridLayout(height = 150)
fig[3, 1] = sl_sublayout
fig[3, 1] = gslidergrit.layout


spielgröße = Observable(10)


# Reaktion auf Änderung der Sliderposition
on(gslidergrit.sliders[1].value) do größe
    ax.limits[] = ((0, größe), (0, größe))
    ax.xticks[] = 0:1:größe
    ax.yticks[] = 0:1:größe
    spielgröße[] = größe
    D[] = Delaunay(größe)
    V[] = voronoi(D[])

    newrange = LinRange(0:0.01: größe)

    for s in pslidergrid.sliders
        s.range[] = newrange
    end
end



input_layout = GridLayout(tellwidth = false)
fig[5, 1] = pslidergrid.layout

fig[6,1] = buttongrid

# Observables fürs Punkte setzten
coords = (
    x = (b = Observable(0.0), r = Observable(0.0)),
    y = (b = Observable(0.0), r = Observable(0.0))
)

# Verbindung mit Positionen Slider
on(pslidergrid.sliders[1].value) do val
    coords.x.b[] = val
    fehler_label.text[] = ""
    fehler_label.textsize = 0.001
end

on(pslidergrid.sliders[2].value) do val
    coords.y.b[] = val
    fehler_label.text[] = ""
    fehler_label.textsize = 0.001
end

on(pslidergrid.sliders[3].value) do val
    coords.x.r[] = val
    fehler_label.text[] = ""
    fehler_label.textsize = 0.001
end

on(pslidergrid.sliders[4].value) do val
    coords.y.r[] = val
    fehler_label.text[] = ""
    fehler_label.textsize = 0.001
end

# Obeservables für das Furchführen des Algorythmus
punkte = Observable(Set{Punkt}())
D = Observable{Any}()
V = Observable(Dict{Punkt, Polygon}())
D[] = Delaunay(spielgröße[])
V[] = voronoi(D[])

"""
on(button[1].clicks) do _
(äquivalent zu on(button[2].clicks) do_)
Zählt die Rundenanzahl runter 
Löscht alle davor erstellten Ploynome auf dem Spielfeld
Fügt den neuen Punkt mit Farbe ins Set punkte hinzu
Setzt alle Punkt aus punkte 
Zeichnet alle Polynome aus voronoi ein
Kontrolliert, ob das Spiel zuende ist.  
"""

# Punkte Setzten
on(buttons[1].clicks) do _
    #Punkt erstellen
    x = coords.x.b[]
    y = coords.y.b[]
    blauer_punkt = Punkt(x, y, "Blau")
    # Auf doppelte Punkte Checken 
    for p in punkte[]
        if x == p.x && y == p.y  
            fehler_label.text[] = "An dieser Stelle ist bereits ein Punkt, bitte setze einen anderen"
            fehler_label.textsize = 30 
            return 
        end
    end
    # Nachschauen, wer an der Reihe ist
    if length(punkte[]) % 2 == 1
        fehler_label.text[] = "Der rote Spieler ist an der Reihe."
        fehler_label.textsize = 30
    else
        #alle zwei züge eine Runde weniger
        if length(punkte[]) % 2 == 1
            current = gslidergrit.sliders[2].value[]
            gslidergrit.sliders[2].value[] = current -1 
        end 
        #Alle Flächen und Punkte aus dem Graphen Löschen 
        empty!(ax)
        empty!(flächen[])
        notify(flächen)
        # Punkt hinzufügen und Delaunay und Voronoi durchführen 
        insert_point!(blauer_punkt, D[])
        global V[] = voronoi(D[], V[])
        push!(punkte[], blauer_punkt)
        notify(punkte)
        #Alles wieder einzeichen 
        scatter!(ax, [Point2f0(p.x, p.y) for p in punkte[]]; color = [p.player == "Blau" ? :blue : :red for p in punkte[]], markersize = 20)
        for key in keys(V[])
            if key.player == "Blau"
                color_area_blue(V[][key])
            else
                color_area_red(V[][key])
            end
        end
    end
    #Am ende des Spieles eine Auswertung vornehmen 
    if gslidergrit.sliders[2].value[] == 0 
        if Blau_O[] > Rot_O[]
            gewinner_label_blau.text[] = "Blau gewinnt! Du hast $(round(Blau_O[], digits=2)) cm^2 besetzt. Das sind" * string(round(anteil_blau[], digits=1)) * "% der Gesammtfläche"
            gewinner_label_blau.textcolor[] = :blue
            gewinner_label_blau.textsize[] = 40
        elseif Rot_O[] > Blau_O[]
            gewinner_label_rot.text[] = "Rot gewinnt! Du hast $(round(Rot_O[], digits=2)) cm^2 besetzt. Das sind" * string(round(anteil_rot[], digits=1)) * "% der Gesammtfläche"
            gewinner_label_rot.textcolor[] = :red
            gewinner_label_rot.textsize[] = 40 
        else
            gleichstand_label.textcolor[] = :black
            gleichstand_label.textsize[] = 40 
        end
    end
end

on(buttons[2].clicks) do _
    x = coords.x.r[]
    y = coords.y.r[]
    roter_punkt = Punkt(x, y, "Rot")
    for p in punkte[]
        if x == p.x && y == p.y  
            fehler_label.text[] = "An dieser Stelle ist bereits ein Punkt, bitte setze einen anderen"
            fehler_label.textsize = 30 
            return 
        end
    end
    if length(punkte[]) % 2 == 0
        fehler_label.text[] = "Der blaue Spieler ist an der Reihe."
        fehler_label.textsize = 30
    else
        if length(punkte[]) % 2 == 1
            current = gslidergrit.sliders[2].value[]
            gslidergrit.sliders[2].value[] = current -1 
        end 
        empty!(ax)
        empty!(flächen[])
        notify(flächen)

        insert_point!(roter_punkt, D[])
        global V[] = voronoi(D[], V[])
        push!(punkte[], roter_punkt)
        notify(punkte)
        scatter!(ax, [Point2f0(p.x, p.y) for p in punkte[]]; color = [p.player == "Blau" ? :blue : :red for p in punkte[]], markersize = 20)
        for key in keys(V[])
            if key.player == "Blau"
                color_area_blue(V[][key])
            else
                color_area_red(V[][key])
            end
        end
    end
    if gslidergrit.sliders[2].value[] == 0 
        if Blau_O[] > Rot_O[]
            gewinner_label_blau.text[] = "Blau gewinnt! Du hast $(round(Blau_O[], digits=2)) cm^2 besetzt. Das sind " * string(round(anteil_blau[], digits=1)) * "% der Gesammtfläche"
            gewinner_label_blau.textcolor[] = :blue
            gewinner_label_blau.textsize[] = 40
        elseif Rot_O[] > Blau_O[]
            gewinner_label_rot.text[] = "Rot gewinnt! Du hast $(round(Rot_O[], digits=2)) cm^2 besetzt. Das sind " * string(round(anteil_rot[], digits=1)) * "% der Gesammtfläche"
            gewinner_label_rot.textcolor[] = :red
            gewinner_label_rot.textsize[] = 40 
        else
            gleichstand_label.textcolor[] = :black
            gleichstand_label.textsize[] = 40 
        end
    end

end

# Flächen als Observabels haben
flächen = Observable(Vector{Tuple{Symbol, Vector{Point2f0}}}())


# Einfärben von Polygomen 
function color_area_blue(polygon::Polygon)
    p = Vector{Point2f0}()
    for i in 1:length(polygon.points)
        x = polygon[i].x
        y = polygon[i].y
        push!(p, Point2f0(x, y))
    end
    poly!(ax, p; color = (:blue, 0.3), strokecolor = (:blue, 1), strokewidth = 2) # ich habe die Grenzen eingezeichnet um sie besser zu sehen. Kannst du lassen oder entfernen.
    push!(flächen[], (:blue, p))
    notify(flächen)
end

function color_area_red(polygon::Polygon)
    p = Vector{Point2f0}()
    for i in 1:length(polygon.points)
        x = polygon[i].x
        y = polygon[i].y
        push!(p, Point2f0(x, y))
    end
    poly!(ax, p; color = (:red, 0.3), strokecolor = (:red, 1), strokewidth = 2)
    push!(flächen[], (:red, p))
    notify(flächen)
end

# Polygomenfläche mit Shoelace Formel
function area_polygone(polygon::Vector{Point2f0})
  n = length(polygon)
  sum = 0.0
  for i in 1:n 
    xi, yi = polygon[i]
    xj, yj = polygon[mod1(i + 1, n)]
    sum += xi * yj -xj *yi
  end
  return 0.5 * abs(sum)
end

anteil_blau = Observable(0.0)
anteil_rot = Observable(0.0)
Rot_O = Observable(0.0)
Blau_O = Observable(0.0)
# Reaktion auf Flächenänderung(Flächeninhalt)
on(flächen) do polys
    blau, rot = 0.0, 0.0
    for (farbe, p) in polys
        a = area_polygone(p)
        if farbe == :blue
            blau += a
        elseif farbe == :red
            rot += a
        end
    end
    Rot_O[] = rot
    Blau_O[] = blau
    gesammt = spielgröße[]^2

    anteil_blau[] = 100 * blau / gesammt
    anteil_rot[]  = 100 * rot  / gesammt

    label_blau.text[]   = "Blau: $(round(blau, digits=2)) (" * string(round(anteil_blau[], digits=1)) * "%)"
    label_rot.text[]    = "Rot:  $(round(rot, digits=2)) (" * string(round(anteil_rot[], digits=1)) * "%)"
    label_gesamt.text[] = "Gesamtfläche: $(round(gesammt, digits=2))"
end

# Counter erstellen
counter_layout = GridLayout()
label_blau   = Label(fig, "Blau: 0.0", textsize = 30)
label_rot    = Label(fig, "Rot: 0.0",  textsize = 30)
label_gesamt = Label(fig, "Gesamt: 0.0", textsize = 30)
counter_layout[1, 1] = label_blau
counter_layout[2, 1] = label_rot
counter_layout[3, 1] = label_gesamt

fig[5,2] = counter_layout


# Menü Kategorien
Kategorien = ["Spiel",
    "Anleitung",
    "Reset des Spieles", "Theorie", "Credits"]


# Menü erstellen
spielmenu = Menu(fig, options = Kategorien, textsize = 30, default = "Spiel")


# Menü einfügen

fig[2, 2] = vgrid!(
    Label(fig, "Menü", textsize = 30, width = 400), spielmenu;
    tellheight = false, width = 500
)


gewinner_layout = GridLayout()
gewinner_label_blau = Label(fig, "Blau gewinnt! Du hast $(round(Blau_O[], digits=2)) cm^2 besetzt. Das sind" * string(round(anteil_blau[], digits=1)) * "% der Gesammtfläche", textsize = 0.001, textcolor = :white)
gewinner_label_rot = Label(fig, "Rot gewinnt! Du hast $(round(Rot_O[], digits=2)) cm^2 besetzt. Das sind" * string(round(anteil_rot[], digits=1)) * "% der Gesammtfläche", textsize = 0.001, textcolor = :white)
gleichstand_label = Label(fig, "Das Spiel endet im Gleichstand!", textsize = 0.001, textcolor = :white)
gewinner_layout[1,1] = gewinner_label_blau
gewinner_layout[1,2] = gewinner_label_rot
gewinner_layout[1,3] = gleichstand_label
fig[4,2] = gewinner_layout

#Anleitung Layout
a_titel = Label(fig, "Anleitung: Verenoi Madniss", textsize = 0.001)
a_text = Label(fig, "", textsize = 0.001)

anleitung_layout = GridLayout()
anleitung_layout[1,1] = a_titel 
anleitung_layout[2,1] = a_text
fig[1,2] = anleitung_layout


fehler_label = Label(fig, "", textsize = 0.001)
fig[3,2] = fehler_label

#Veränderung beim Auswählen des Menüs
on(spielmenu.selection) do eintrag 
    if eintrag == "Spiel"
        a_titel.text[] = ""
        a_text.text[] = ""
        a_text.textsize = 0.001
        a_titel.textsize = 0.001
        fehler_label.text[] = ""
        fehler_label.textsize = 0.001
    elseif eintrag == "Anleitung"
        a_titel.text[] = "Voronoi Madniss: Anleitung"
        a_text.text[] = "Bei diesem Spiel setzt ihr Punkte auf das Spielfeld und derjenige, der den Größten Anteil der Fläche eingefärbt hat, hat gewonnen.\n 
            Am Anfang solltet ihr euch entscheiden, wie Groß euer Spielfeld ist mit dem Spielfeldgrößen Slider. \n 
            Das Ändern der Spielfeldgröße nach dem Setzen des ersten Punktes kann zu fehlern führen.\n
            Mit dem zweiten Slider könnt ihr festlegen wie lange euer Spiel gehen soll. \n
            Es ist möglich diesen Wert auch nachträglich zu verändern, aber für mehr Spielspaß raten wir dagegen. \n
            Der blaue Spieler beginnt. \n
            Setzt dann abwechselnd mithilfe der x und y Slider eurer Farbe Punkte auf das Spielfeld. \n
            Die Fläche, die am Nächsten zu eurem Punkt liegt, wir in eurer Farbe eingefärbt. \n
            Derjenige, der am Ende die meiste Fläche hat, hat gewonnen. \n
            Viel Spaß beim Spielen!"
        a_text.textsize = 25 
        a_titel.textsize = 40
        fehler_label.text[] = ""
        fehler_label.textsize = 0.001
    elseif eintrag == "Reset des Spieles"
        a_titel.text[] = ""
        a_text.text[] = ""
        a_text.textsize = 0.001
        a_titel.textsize = 0.001

        fehler_label.text[] = ""
        fehler_label.textsize = 0.001

        empty!(punkte[])
        notify(punkte)

        empty!(flächen[])
        notify(flächen)  

        empty!(ax)

        D[] = Delaunay(spielgröße[])
        V[] = voronoi(D[])

        gslidergrit.sliders[2].value[] = 10
        gewinner_label_blau.textsize = 0.001
        gewinner_label_rot.textsize = 0.001
        gleichstand_label.textsize = 0.001    
        
    elseif eintrag == "Theorie"
        a_titel.text[] = "Voronoi Diagramme und Delaunay"
        a_text.text[] = "Voronoi Diagramme teilen eine Fläche in Gebiete ein. \n 
        Diese Gebiete sind dadurch gekennzeichnet, dass alle Punkte in diesem Gebiet einem Punkt am nächsten liegen.\n 
        Diese Punkte sind die Ursprünge, um die die Polygome gebildet werden, die diese eigensacht erfüllen. \n 
        Zur Erstellung dieser Diagramme wird Delaunay benutz. \n 
        Dabei werden Delaunay Kreise verwändet, wobei die damit zusammenhängende Triangulierung \n 
        diese Polygone miterstellt. \n 
        Voronoi ist genutzt in der Robotik, Computergrafik, Spiele und anderen Einflussbereichen. "
        a_text.textsize = 25 
        a_titel.textsize = 40
        fehler_label.text[] = ""
        fehler_label.textsize = 0.001

    elseif eintrag == "Credits"
        a_titel.text[] = "Voronoi Madniss ersteller:"
        a_text.text[] = "Orhan Cavus \n Chris Kyrill Hansen \n Emilia Luisa Schultz \n 
        in Rahmen des Programmierprojektes des Computerorientierte Mathematik 2 Moduls"
        a_text.textsize = 25
        a_titel.textsize = 40

    end
end

fig


