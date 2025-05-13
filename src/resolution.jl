# This file contains methods to solve an instance (heuristically or with CPLEX)
using CPLEX


include("generation.jl")

TOL = 0.00001

"""
Solve an instance with CPLEX
"""
function cplexSolve(grille::Matrix{Int64})

    R,C = size(grille) #R : nombre de ligne, C: nombre de colonnes
    # ON recupere les cases avec des chiffres non nuls
    N = [(i,j, grille[i,j]) for i in 1:R, j in 1:C if grille[i,j]>0]
    n_indices = 1:length(N)

    rectangles = []
    for (i_idx,(ri,ci,val)) in enumerate(N)
        for h in 1:R
            for w in 1:C 
                if h*w == val
                    for r in max(1,ri-h+1):min(ri, R-h+1)
                        for c in max(1,ci-w+1):min(ci,C-w+1)
                            push!(rectangles,(r,c,h,w,i_idx))
                        end
                    end
                end
            end
        end
    end

    # Create the model
    m = Model(CPLEX.Optimizer)


    @variable(m, x[1:length(rectangles)],Bin)

    #Contraintes
    # Chaques case numeroté n'a qu'un seul rectangle associé
    for i_idx in n_indices
        @constraint(m, sum(x[k] for (k,(_,_,_,_,idx)) in enumerate(rectangles) if idx==i_idx)==1)
    end

    #chaque case n'a qu'un seul rectangle associe
    for i in 1:R,j in 1:C 
        @constraint(m,sum(x[k] for (k,(r,c,h,w,_)) in enumerate(rectangles) if i in r:(r+h-1) && j in c:(c+w-1))==1)
    end


    # Start a chronometer
    start = time()

    # Solve the model
    optimize!(m)
    elapsed = time() - start
    
    # Vérification du statut 
    status = termination_status(m)
    is_optimal = primal_status(m) == MOI.FEASIBLE_POINT
    
    if is_optimal
         x_values = [value(x[k]) for k in 1:length(x)]
    else
        println("Aucune solution optimale trouvée.")
        x_values = []
    end


    # Return:
    # 1 - true if an optimum is found
    # 2 - the resolution time
    return primal_status(m) == MOI.FEASIBLE_POINT, time() - start,x_values,rectangles,N,R,C
    
end

"""
Heuristically solve an instance
"""
function heuristicSolve()

    # TODO
    println("In file resolution.jl, in method heuristicSolve(), TODO: fix input and output, define the model")
    
end 

function writeSolution(io, x, R, C, N, rectangles)
    # Initialise une matrice de 0
    sol = fill(0, R, C)

    # Remplit la matrice avec les identifiants des rectangles actifs
    for (k, (r, c, h, w, _)) in enumerate(rectangles)
        if x[k] > 0.5
            for i in r:(r + h - 1), j in c:(c + w - 1)
                sol[i, j] = k
            end
        end
    end

    # Écriture dans le fichier sous forme de matrice CSV
    for i in 1:R
        println(io, join(sol[i, :], ","))  # écrit chaque ligne avec des virgules
    end
end

"""
Solve all the instances contained in "../data" through CPLEX and heuristics

The results are written in "../res/cplex" and "../res/heuristic"

Remark: If an instance has previously been solved (either by cplex or the heuristic) it will not be solved again
"""
function solveDataSet()

    #baseDir = dirname(@__FILE__)
    dataFolder = "./data/"
    resFolder = "./res/"
    #dataFolder = joinpath(baseDir, "..", "data")
    #resFolder = joinpath(baseDir, "..", "res")

    # Array which contains the name of the resolution methods
    resolutionMethod = ["cplex"]
    #resolutionMethod = ["cplex", "heuristique"]

    # Array which contains the result folder of each resolution method
    resolutionFolder = resFolder .* resolutionMethod

    # Create each result folder if it does not exist
    for folder in resolutionFolder
        if !isdir(folder)
            mkdir(folder)
        end
    end
            
    global isOptimal = false
    global solveTime = -1

    # For each instance
    # (for each file in folder dataFolder which ends by ".txt")
    for file in filter(x->occursin(".txt", x), readdir(dataFolder))  
        
        println("-- Resolution of ", file)
        t = readInputFile(dataFolder * file)
        #t = readInputFile(joinpath(dataFolder, file))

        
        
        # For each resolution method
        for methodId in 1:size(resolutionMethod, 1)
            
            outputFile = resolutionFolder[methodId] * "/" * file
            #outputFile = joinpath(resolutionFolder[methodId], file)

            # If the instance has not already been solved by this method
            if !isfile(outputFile)
                
                fout = open(outputFile, "w")  

                resolutionTime = -1
                isOptimal = false
                
                # If the method is cplex
                if resolutionMethod[methodId] == "cplex"
                    
                    
                    # Solve it and get the results
                    isOptimal, resolutionTime, x, rectangles,N,R,C = cplexSolve(t)
                    
                    # If a solution is found, write it
                    #if isOptimal
                    #    writeSolution(fout, [value(xi) for xi in x], R,C, N, rectangles)
                    #end

                # If the method is one of the heuristics
                else
                    
                    isSolved = false

                    # Start a chronometer 
                    startingTime = time()
                    
                    # While the grid is not solved and less than 100 seconds are elapsed
                    while !isOptimal && resolutionTime < 100
                        
                        
                        # Solve it and get the results
                        isOptimal, resolutionTime = heuristicSolve()

                        # Stop the chronometer
                        resolutionTime = time() - startingTime
                        
                    end

                    # Write the solution (if any)
                    if isOptimal

                        # TODO
                        println("In file resolution.jl, in method solveDataSet(), TODO: write the heuristic solution in fout")
                        
                    end 
                end

                println(fout, "solveTime = ", resolutionTime) 
                println(fout, "isOptimal = ", isOptimal)
                
                close(fout)
            end


            # Display the results obtained with the method on the current instance
            #include(outputFile)
            println(resolutionMethod[methodId], " optimal: ", isOptimal)
            println(resolutionMethod[methodId], " time: " * string(round(solveTime, sigdigits=2)) * "s\n")
        end         
    end 
end
