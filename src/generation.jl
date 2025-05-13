# This file contains methods to generate a data set of instances (i.e., sudoku grids)
include("io.jl")

"""
Generate an R*C grid

Argument
- R,C: size of the grid
- les tailles minimale et maximale autorisees pour les aires des rectangles
"""
function generateInstance(R::Int, C::Int; taille_min::Int=1, taille_max::Int=6)

    occupe = falses(R, C)  # Marque les cases deja prises
    grille = zeros(Int, R, C)  # Grille de sortie avec 0 partout
    rectangles = [] # repertorie les rectangles

    essais_max = 1000 
    essais = 0

    while essais < essais_max
        essais += 1

        aire = rand(taille_min:taille_max)
        tailles = [(h, w) for h in 1:R, w in 1:C if h * w == aire]

        if isempty(tailles)
            continue
        end

        h, w = rand(tailles)

        lignes = 1:(R - h + 1)
        colonnes = 1:(C - w + 1)

        positions = [(r, c) for r in lignes, c in colonnes if all(!occupe[r+i, c+j] for i in 0:h-1, j in 0:w-1)]

        if isempty(positions)
            continue
        end

        r, c = rand(positions)

        for i in 0:h-1, j in 0:w-1
            occupe[r+i, c+j] = true
        end

        # Choisir une case du rectangle pour y ecrire l'aire
        ri = r + rand(0:h-1)
        ci = c + rand(0:w-1)
        grille[ri, ci] = aire

        push!(rectangles, (r, c, h, w))

        if all(occupe)
            break
        end
    end

    return grille
end




"""
Generate all the instances

Remark: a grid is generated only if the corresponding output file does not already exist
"""
function generateDataSet()
    base_path = joinpath(@__DIR__, "..", "data2")
    taille_max = 0
    # For each grid size considered
    for size in [23, 24, 25,26, 27,28]
        taille_max = size + 10

        # Generate 10 instances
        for instance in 1:5
            #fileName = "../Projet/jeu1/data/instance_t" * string(size) * "_" * string(instance) * ".txt"
            fileName = joinpath(base_path, "instance_t$(size)_$(instance).txt")
            if !isfile(fileName)
                println("-- Generating file " * fileName)
                grille = generateInstance(size, size; taille_min=1, taille_max=taille_max)

                saveInstance(grille, fileName)
            end 
        end

    end
end
    




