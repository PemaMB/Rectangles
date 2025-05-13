# This file contains functions related to reading, writing and displaying a grid and experimental results

using JuMP
using Plots
import GR

using Glob
using DataFrames
using XLSX

"""
Read an instance from an input file

- Argument:
inputFile: path of the input file
"""
function readInputFile(inputFile::String)

    # Open the input file
    datafile = open(inputFile)

    data = readlines(datafile)
    close(datafile)
    R = length(split(data[1], ","))
    C = length(data)
    lineNb = 1
    grille = Matrix{Int}(undef, R,C)
    # For each line of the input file
    for line in data
        lineSplit = split(line, ",")
        for i in 1:R 
           grille[lineNb, i] = parse(Int64,lineSplit[i])
        end
        lineNb +=1
    end
    return grille
end

function displayGrid(grille::Matrix{Int64})

    R,C = size(grille)
    blockSize = round.(Int, sqrt(R))
    
    # Display the upper border of the grid
    println(" ", "-"^(3*R+blockSize-2)) 
    
    # For each cell (l, c)
    for l in 1:R
        for c in 1:C

            if rem(c, blockSize) == 1 && c ==1
                print("|")
            end  
            
            if grille[l, c] == 0
                print(" -")
            else
                if grille[l, c] < 10
                    print(" ")
                end
                
                print(grille[l, c])
            end
            print(" ")
        end
        println("|")

    end
    println(" ", "-"^(3*R+blockSize-2)) 
end

function displaySolution(x, R,C,N,grille)
    # On prépare une grille vide pour affichage (avec bords)
    affichage = [fill(' ', C * 3 + 1) for _ in 1:(R * 2 + 1)]

    # Dessiner tous les rectangles utilisés
    for (k, (r, c, h, w, _)) in enumerate(rectangles)
        if x[k] > 0.5
            top = (r - 1) * 2 + 1
            left = (c - 1) * 3 + 1
            bottom = top + h * 2
            right = left + w * 3

            # Bordures horizontales
            for j in left:right
                affichage[top][j] = '-'      # top
                affichage[bottom][j] = '-'   # bottom
            end

            # Bordures verticales
            for i in top:bottom
                affichage[i][left] = '|'     # left
                affichage[i][right] = '|'    # right
            end

            # Coins
            affichage[top][left] = '+'
            affichage[top][right] = '+'
            affichage[bottom][left] = '+'
            affichage[bottom][right] = '+'
        end
    end

    # Remplir les chiffres
    for (i, j, val) in N
        row = (i - 1) * 2 + 2
        col = (j - 1) * 3 + 2
        affichage[row][col] = string(val)[1]  # affiche un seul chiffre (si val < 10)
    end

    # Affichage final
    println("\n=== Grille Résolue ===")
    for row in affichage
        println(String(row))
    end
end

"""
Create a pdf file which contains a performance diagram associated to the results of the ../res folder
Display one curve for each subfolder of the ../res folder.

Arguments
- outputFile: path of the output file

Prerequisites:
- Each subfolder must contain text files
- Each text file correspond to the resolution of one instance
- Each text file contains a variable "solveTime" and a variable "isOptimal"
"""
function performanceDiagram(outputFile::String)

    resultFolder = "./res/"
    
    # Maximal number of files in a subfolder
    maxSize = 0

    # Number of subfolders
    subfolderCount = 0

    folderName = Array{String, 1}()

    # For each file in the result folder
    for file in readdir(resultFolder)

        path = resultFolder * file
        
        # If it is a subfolder
        if isdir(path)
            
            folderName = vcat(folderName, file)
             
            subfolderCount += 1
            folderSize = size(readdir(path), 1)

            if maxSize < folderSize
                maxSize = folderSize
            end
        end
    end

    # Array that will contain the resolution times (one line for each subfolder)
    results = Array{Float64}(undef, subfolderCount, maxSize)

    for i in 1:subfolderCount
        for j in 1:maxSize
            results[i, j] = Inf
        end
    end

    folderCount = 0
    maxSolveTime = 0

    # For each subfolder
    for file in readdir(resultFolder)
            
        path = resultFolder * file
        
        if isdir(path)

            folderCount += 1
            fileCount = 0

            # For each text file in the subfolder
            for resultFile in filter(x->occursin(".txt", x), readdir(path))

                fileCount += 1
                include(path * "/" * resultFile)

                if isOptimal
                    results[folderCount, fileCount] = solveTime

                    if solveTime > maxSolveTime
                        maxSolveTime = solveTime
                    end 
                end 
            end 
        end
    end 

    # Sort each row increasingly
    results = sort(results, dims=2)

    println("Max solve time: ", maxSolveTime)

    # For each line to plot
    for dim in 1: size(results, 1)

        x = Array{Float64, 1}()
        y = Array{Float64, 1}()

        # x coordinate of the previous inflexion point
        previousX = 0
        previousY = 0

        append!(x, previousX)
        append!(y, previousY)
            
        # Current position in the line
        currentId = 1

        # While the end of the line is not reached 
        while currentId != size(results, 2) && results[dim, currentId] != Inf

            # Number of elements which have the value previousX
            identicalValues = 1

             # While the value is the same
            while results[dim, currentId] == previousX && currentId <= size(results, 2)
                currentId += 1
                identicalValues += 1
            end

            # Add the proper points
            append!(x, previousX)
            append!(y, currentId - 1)

            if results[dim, currentId] != Inf
                append!(x, results[dim, currentId])
                append!(y, currentId - 1)
            end
            
            previousX = results[dim, currentId]
            previousY = currentId - 1
            
        end

        append!(x, maxSolveTime)
        append!(y, currentId - 1)

        # If it is the first subfolder
        if dim == 1

            # Draw a new plot
            plt = plot(x, y, label = folderName[dim], legend = :bottomright, xaxis = "Time (s)", yaxis = "Solved instances",linewidth=3)

        # Otherwise 
        else
            # Add the new curve to the created plot
            #savefig(plot!(x, y, label = folderName[dim], linewidth=3), outputFile)
            plot!(plt, x, y, label = folderName[dim], linewidth=3)
        end 
        savefig(plt, outputFile)
    end
end 

"""
Create a latex file which contains an array with the results of the ../res folder.
Each subfolder of the ../res folder contains the results of a resolution method.

Arguments
- outputFile: path of the output file

Prerequisites:
- Each subfolder must contain text files
- Each text file correspond to the resolution of one instance
- Each text file contains a variable "solveTime" and a variable "isOptimal"
"""
function resultsArray(outputFile::String)
    
    resultFolder = "./res2/"
    dataFolder = "./data2/"
    
    # Maximal number of files in a subfolder
    maxSize = 0

    # Number of subfolders
    subfolderCount = 0

    # Open the latex output file
    fout = open(outputFile, "w")

    # Print the latex file output
    println(fout, raw"""\documentclass{article}

\usepackage[french]{babel}
\usepackage [utf8] {inputenc} % utf-8 / latin1 
\usepackage{multicol}

\setlength{\hoffset}{-18pt}
\setlength{\oddsidemargin}{0pt} % Marge gauche sur pages impaires
\setlength{\evensidemargin}{9pt} % Marge gauche sur pages paires
\setlength{\marginparwidth}{54pt} % Largeur de note dans la marge
\setlength{\textwidth}{481pt} % Largeur de la zone de texte (17cm)
\setlength{\voffset}{-18pt} % Bon pour DOS
\setlength{\marginparsep}{7pt} % Séparation de la marge
\setlength{\topmargin}{0pt} % Pas de marge en haut
\setlength{\headheight}{13pt} % Haut de page
\setlength{\headsep}{10pt} % Entre le haut de page et le texte
\setlength{\footskip}{27pt} % Bas de page + séparation
\setlength{\textheight}{668pt} % Hauteur de la zone de texte (25cm)

\begin{document}""")

    header = raw"""
\begin{center}
\renewcommand{\arraystretch}{1.4} 
 \begin{tabular}{l"""

    # Name of the subfolder of the result folder (i.e, the resolution methods used)
    folderName = Array{String, 1}()

    # List of all the instances solved by at least one resolution method
    solvedInstances = Array{String, 1}()

    # For each file in the result folder
    for file in readdir(resultFolder)

        path = resultFolder * file
        
        # If it is a subfolder
        if isdir(path)

            # Add its name to the folder list
            folderName = vcat(folderName, file)
             
            subfolderCount += 1
            folderSize = size(readdir(path), 1)

            # Add all its files in the solvedInstances array
            for file2 in filter(x->occursin(".txt", x), readdir(path))
                solvedInstances = vcat(solvedInstances, file2)
            end 

            if maxSize < folderSize
                maxSize = folderSize
            end
        end
    end

    # Only keep one string for each instance solved
    unique(solvedInstances)

    # For each resolution method, add two columns in the array
    for folder in folderName
        header *= "rr"
    end

    header *= "}\n\t\\hline\n"

    # Create the header line which contains the methods name
    for folder in folderName
        header *= " & \\multicolumn{2}{c}{\\textbf{" * folder * "}}"
    end

    header *= "\\\\\n\\textbf{Instance} "

    # Create the second header line with the content of the result columns
    for folder in folderName
        header *= " & \\textbf{Temps (s)} & \\textbf{Optimal ?} "
    end

    header *= "\\\\\\hline\n"

    footer = raw"""\hline\end{tabular}
\end{center}

"""
    println(fout, header)

    # On each page an array will contain at most maxInstancePerPage lines with results
    maxInstancePerPage = 30
    id = 1

    # For each solved files
    for solvedInstance in solvedInstances

        # If we do not start a new array on a new page
        if rem(id, maxInstancePerPage) == 0
            println(fout, footer, "\\newpage")
            println(fout, header)
        end 

        # Replace the potential underscores '_' in file names
        print(fout, replace(solvedInstance, "_" => "\\_"))

        # For each resolution method
        for method in folderName

            path = resultFolder * method * "/" * solvedInstance

            # If the instance has been solved by this method
            if isfile(path)

                include(path)

                println(fout, " & ", round(solveTime, digits=2), " & ")

                if isOptimal
                    println(fout, "\$\\times\$")
                end 
                
            # If the instance has not been solved by this method
            else
                println(fout, " & - & - ")
            end
        end

        println(fout, "\\\\")

        id += 1
    end

    # Print the end of the latex file
    println(fout, footer)

    println(fout, "\\end{document}")

    close(fout)
    
end 

"""
Save the solving time and size in an excel file
"""
function timesize(fichier_excel::String)
    repertoire = "./res/cplex"
    fichiers = glob("instance_t*_*.txt", repertoire)
    data = DataFrame(taille=Int[], solveTime=Float64[], isOptimal=Bool[])
    for fichier in fichiers
        println("Traitement du fichier : ", fichier)
        m = match(r"instance_t(\d+)_\d+\.txt", basename(fichier))
        if m === nothing
            @warn "Nom de fichier non conforme : $fichier"
            continue
        end
        taille = parse(Int, m.captures[1])

        lignes = readlines(fichier)
        solve_time = nothing
        is_optimal = nothing

        for ligne in lignes
            if occursin("solveTime", ligne)
                solve_time = parse(Float64, split(ligne, "=")[2])
            elseif occursin("isOptimal", ligne)
                is_optimal = strip(split(ligne, "=")[2]) == "true"
            end
        end

        if solve_time !== nothing && is_optimal !== nothing
            push!(data, (taille, solve_time, is_optimal))
        else
            @warn "Informations manquantes dans $fichier"
        end
    end

    # Supprimer le fichier Excel s’il existe déjà
    if isfile(fichier_excel)
        rm(fichier_excel)
    end

    XLSX.writetable(fichier_excel, collect(eachcol(data)), names(data))
    println("✅ Données écrites dans $fichier_excel avec succès.")
end
"""
Save a grid in a text file

Argument
- t: 2-dimensional array of size n*n
- outputFile: path of the output file
"""
function saveInstance(t::Matrix{Int64}, outputFile::String)

    R,C = size(t)

    # Open the output file
    writer = open(outputFile, "w")

    # For each cell (l, c) of the grid
    for l in 1:R
        for c in 1:C

            # Write its value
            if t[l, c] == 0
                print(writer, "0")
            else
                print(writer, t[l, c])
            end

            if c != C
                print(writer, ",")
            else
                println(writer, "")
            end
        end
    end

    close(writer)
    
end 