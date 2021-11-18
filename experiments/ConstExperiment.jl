using CSV
using DataFrames	
using Random
using MLDataUtils
using BenchmarkTools

using GP_NLS

df_names = ["airfoil", "cars", "concrete", "energyCooling", "energyHeating", "grossOutput",
     "qsarAquaticToxicity", "wineRed", "wineWhite", "yachtHydrodynamics"]

# We can pass the name of the datasets that the process should run. If none
# is given, then it runs all datasets in ds_names sequentially
if size(ARGS, 1) > 0
    df_names = intersect(Set(df_names), Set(ARGS))
    if length(df_names) == 0
        println("None of the past dataset names exist.")
        exit()
    else
        println("Running now for datasets $(df_names)")
    end
else
    println("Executando todos os datasets sequencialmente ($(df_names))")
end

functionSet = defaultFunctionSet # Let's use the default sets provided

constSet = Const[
    Const(0.0),

    Const(1.5707),
    Const(3.1415),

    Const(-1.5707),
    Const(-3.1415),
    
    Const(1.0),
    Const(10.0),
    Const(100.0),

    Const(-1.0),
    Const(-10.0),
    Const(-100.0),
]

# Retrieving previous results or preparing a DataFrame to save new ones
df_results = try
    CSV.File("./results/ConstResults.csv") |> DataFrame
catch err
    DataFrame(Dataset=[], Execution=[], Time=[], Fitness_train=[],
        Fitness_test=[], Number_of_nodes=[], Number_of_nodes_real=[], Depth=[], Expression=[])
end

for df_name in df_names
    print("Testing the data set $df_name: ")

    df_data = CSV.File("../datasets/$(df_name).csv") |> DataFrame

    # Scramble the data, as some databases usually saves in some logical order
    df_data = df_data[Random.shuffle(1:end), :]

    # Let's create the terminal set. It will be the combination of variables and constants only
    varSet = Union{Var, WeightedVar}[
        Var(var_name, i) for (i, var_name) in enumerate(names(df_data)[1:end-1])
    ]

    # Finally, the terminals will be the junction of constants, erc and variables
    terminalSet = Array{Union{Const, Var, WeightedVar, ERC}}(vcat(constSet, varSet))

    # Filtering results file to see how many runs we have
    df_filtro = df_results[df_results.Dataset .== df_name, :]

    for i in 1:30
        # Let's see whether or not you have this execution data
        if size(df_filtro[df_filtro.Execution .== i, :], 1) == 0
            print("$i ")

            # Separating everything into training and testing
            train, test = splitobs(df_data, at = 0.7)
    
            # Separating training and testing into X and y
            train_X = convert(Matrix{Float64}, train[:, 1:end-1])
            train_y = convert(Vector{Float64}, train[:, end])
            
            test_X  = convert(Matrix{Float64}, test[:, 1:end-1])
            test_y  = convert(Vector{Float64}, test[:, end])

            # Saving @elapsed macro runtime and the best solution
            exec_time = @elapsed (bestsol = GP(
                train_X,
                train_y,
                functionSet,
                terminalSet,
                minDepth               = 1,
                maxDepth               = 10,
                maxSize                = 75,
                popSize                = 250,
                gens                   = 400,
                mutationRate           = 0.25,
                elitism                = true,
                verbose                = true,
                init_method            = "PTC2", 
                lm_optimization        = false,
                keep_linear_transf_box = false 
            ))

            # Saving execution results
            push!(df_results, (
                df_name,
                i,
                exec_time,
                fitness(bestsol, train_X, train_y),
                fitness(bestsol, test_X, test_y),
                numberofnodes(bestsol),
                true_numberofnodes(bestsol),
                depth(bestsol),
                getstring(bestsol),
            ))
            
            # writing after each repetition
            CSV.write("./results/ConstResults.csv", df_results)
            
            # Let's force the garbage collector
            GC.gc()
        end
    end

    # End for the dataset, let's go to the next
    println("Finished for dataset $(df_name).")
end