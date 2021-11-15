# Author:  Guilherme Aldeia
# Contact: guilherme.aldeia@ufabc.edu.br
# Version: 1.0.0
# Last modified: 13-11-2021 by Guilherme Aldeia


"""Entry point of GP_NLS module.
"""


__precompile__()

module GP_NLS

export 
    # Different Tree nodes 
    Func, Const, Var, WeightedVar, ERC,

    # Default set of nodes to allow off-the-shelf usage
    defaultFunctionSet, defaultConstSet, defaultERCSet,

    # GP algorrithm and evaluate/predict
    GP, evaluate,

    # Inspection of final expression
    getstring, fitness, numberofnodes, depth,

    # Correctly counting the coefficients in GP-NLS expanded trees
    true_numberofnodes, true_depth

using LsqFit
using Random
using LinearAlgebra
using Statistics


# Different nodes implemented to build up expression trees
include("NodeContent.jl")

# Structure of expression trees: inner nodes and terminal nodes 
include("TreeStructure.jl")

# Auxiliary methods to manipulate trees
include("Utils.jl")

# Different initialization methods for the first population
include("Initialization.jl")

# Evaluation of trees and fitness (RMSE)
include("Evaluation.jl")

# GP algorithm
include("Evolutionary.jl")

# Non-linear least squares optimization
include("LsqOptimization.jl")

end # module