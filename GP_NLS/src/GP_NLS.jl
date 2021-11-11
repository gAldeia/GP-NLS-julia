module GP_NLS

export Func, Const, Var, WeightedVar, ERC,                 # Possibilitar criação do conteúdo dos nós
       defaultFunctionSet, defaultConstSet, defaultERCSet, # Conjuntos padrões para exemplo ou uso off-the-shelf
       GP, evaluate,                                       # implementação do GP e evaluate/predict
       getstring, fitness, numberofnodes, depth,           # Inspecionar a expressão final
       true_numberofnodes, true_depth                      # Contagem adicional de nós e profundidades

using LsqFit
using Random
using LinearAlgebra
using Statistics

# Primeiro vamos criar estruturas que serão utilizadas nos nós internos da árvore de expressão
include("Nodes.jl")

# Agora vamos criar estruturas para ser o esqueleto da árvore
include("Trees.jl")

# Funções auxiliares para manipular as estruturas de árvores
include("Utils.jl")

# Funções para criar indivíduos e populações
include("Initialization.jl")

# Funções de avaliação de árvores (eval e fitness)
include("Evaluation.jl")

# Funções relacionadas ao algoritmo evolutivo.
include("Evolutionary.jl")

# Incluindo as funções de otimização não lineares. Todas aqui são internas ao pacote
include("LsqOptimization.jl")

end # module