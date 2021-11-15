# Author:  Guilherme Aldeia
# Contact: guilherme.aldeia@ufabc.edu.br
# Version: 1.0.0
# Last modified: 13-11-2021 by Guilherme Aldeia


"""Function that takes any node of a tree (```AbstractNode```), and
an data matrix ```X``` (where each row is an observation and each column is
a variable), and evaluate the prediction for each observation in ```X```.
The function makes a recursive call along the tree node and evaluates the
expression using the matrix variable columns that exist in the tree.

If the node is a ```InternalNode```, the recursive call is made with its children and the
result is used as arguments of the node function.
    
If it is a ```TerminalNode``` with content ```Const```, a vector with
```size(X, 1)``` repeatedly containing the constant is returned.

If it is a ```TerminalNode``` with content ```Var``` or ```WeightedVar```, the
column of the index ```Var.var_idx``` of ```X``` will be used to extract 
the value of the variable from the matrix.

    evaluate(node::Union{TerminalNode, InternalNode}, X::Matrix{Float64})::Vector{Float64}

Implements a multiple dispatch for the case of ```TerminalNode``` and
```InternalNode```.
"""
function evaluate(node::TerminalNode, X::Matrix{Float64})::Vector{Float64}
    if typeof(node.terminal) == Var

        return X[:, node.terminal.var_idx]
    elseif typeof(node.terminal) == WeightedVar

        return X[:, node.terminal.var_idx].*node.terminal.weight
    else

        return ones(size(X,1)) * node.terminal.value
    end
end

function evaluate(node::InternalNode, X::Matrix{Float64})::Vector{Float64}
    args = map(node.children[1:node.func.arity]) do child
        evaluate(child, X)
    end

    return node.func.func(args...)
end


"""Function that measures the fitness of a given tree, in relation to an
training data matrix ```X::Matrix{Float64}``` and a vector of expected results
```y::Vector{Float64}```.

    fitness(tree::AbstractNode, X::Matrix{Float64}, y::Vector{Float64})::Float64

The fitness is calculated using the RMSE, and this method returns an infinite
fitness if the tree fails to evaluate --- forcing the selective pressure to
likely eliminate the individual from the population without having to think
about protected operations.
"""
function fitness(tree::AbstractNode, X::Matrix{Float64}, y::Vector{Float64})::Float64

    try
        RMSE = sqrt( mean( (evaluate(tree, X) .- y).^2 ) )
        
        isfinite(RMSE) ? RMSE : Inf
    catch err
        return Inf
    end
end