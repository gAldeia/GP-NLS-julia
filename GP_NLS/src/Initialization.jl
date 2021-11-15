# Author:  Guilherme Aldeia
# Contact: guilherme.aldeia@ufabc.edu.br
# Version: 1.0.0
# Last modified: 15-11-2021 by Guilherme Aldeia


"""Function that receives the set of terminal contents and creates a random
terminal node.

    _create_random_terminal(
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}})::TerminalNode

Creating a terminal node involves an additional verification step for
the case of ERC, which must be replaced with a constant within the range
specified.
"""
function _create_random_terminal(
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}})::TerminalNode

    t = tSet[Random.rand(1:end)]
        
    if typeof(t) == ERC
        randVal = Random.rand()
        range = t.u_bound - t.l_bound
        
        return TerminalNode(Const( (randVal*range)+ t.l_bound ))
    else
        # Here is a variable, weighted varible, or constant
        return TerminalNode(t) 
    end
end


"""Function that creates a tree using the _grow_ method, inspired by Koza's
original work. Receives a set of ```fSet::Vector{Func}``` functions that will
be used in the internal nodes, a set of
```tSet::Vector{Union{Var, WeightedVar, Const, ERC}}``` terminals, and a maximum
depth of ```maxDepth::Int64``` allowed.

Returns any tree with maximum depth ```maxDepth``` created using the functions
and terminal sets.

     grow(fSet::Vector{Func}, tSet::Vector{Union{Var, WeightedVar, Const, ERC}},
            maxDepth::Int64)::AbstractNode

Note that there is no minimum size, meaning that a single-node tree can be
returned. The maximum depth considers weighted variables as a single node.
"""
function grow(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    maxDepth::Int64)::AbstractNode

    if maxDepth <= 1 || Random.rand() < 1/maxDepth
        return _create_random_terminal(tSet)
    else
        idx = Random.rand(1:size(fSet, 1))
        
        return InternalNode(
            fSet[idx],
            AbstractNode[grow(fSet, tSet, maxDepth-1) for _ in 1:fSet[idx].arity]
        )
    end
end


"""Function that creates a tree using the _full_ method, inspired by Koza's
original work. Receives a set of ```fSet::Vector{Func}``` functions, a set of
```tSet::Vector{Union{Var, WeightedVar, Const, ERC}}``` terminals, and a maximum
depth of ```maxDepth::Int64``` allowed.

Returns any tree with maximum depth ```maxDepth``` and using the
contents of past functions and terminals.

    full(fSet::Vector{Func}, tSet::Vector{Union{Var, WeightedVar, Const, ERC}},
            maxDepth::Int64)::AbstractNode
"""
function full(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    maxDepth::Int64)::AbstractNode

    if maxDepth <= 1
        return _create_random_terminal(tSet)
    else
        idx = Random.rand(1:size(fSet, 1))
    
        return InternalNode(
            fSet[idx],
            AbstractNode[full(fSet, tSet, maxDepth-1) for _ in 1:fSet[idx].arity]
        )
    end    
end


"""Tree creation with the Probabilistic Tree Creator 2 (PTC2) method, described
in __Two Fast Tree-Creation Algorithms for Genetic Programming__, by Sean Luke.

This method looks like Koza's _full_ method, but in addition to respecting a
limit of ```maxDepth``` depth, it also respects a limit of number of nodes 
```expctdSize```.

PTC2 ensures that the depth does not exceed the maximum (in our case, weighted
variables count as depth 1), and ensures that the number of nodes does not
exceed the expected value added to the highest arity between the functions,
that is, ``expctdSize + max(arity(f)), f in fSet``.

    PTC2(
        fSet::Vector{Func},
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}},
        maxDepth::Int64,
        expctdSize::Int64)::AbstractNode

Here we adopt that the chance to select a ``t`` terminal will be uniform for
all possible terminals, and the chance to select a function will also follow
the same logic.
"""
function PTC2(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    maxDepth::Int64,
    expctdSize::Int64)::AbstractNode

    if expctdSize == 1 || maxDepth <= 1 # select random terminal and return it
        return _create_random_terminal(tSet)
    else
        f = fSet[Random.rand(1:end)] # Choose a non-terminal to be the root

        # Creating with allocated and empty positions
        root = InternalNode(f, Array{AbstractNode}(undef, f.arity))

        currSize = 1 # current tree size

        # Let's use a simple array to simulate the random queue.
        # We store tuples with ("reference" to child position, node depth in tree)
        randQueue = Tuple{Function, Int64}[] 

        for i in 1:root.func.arity # simulating pointers to update children
            push!(randQueue, (x -> root.children[i] = x, 1))
        end

        while size(randQueue)[1]+currSize < expctdSize && size(randQueue)[1] > 0
            
            # Taking out a random node of the queue
            let randNode = Random.rand(1:size(randQueue)[1])
                nodeUpdater, nodeDepth = randQueue[randNode]
                deleteat!(randQueue, randNode)

                if nodeDepth >= maxDepth # Draw terminal and place to maximum depth
                    terminal = _create_random_terminal(tSet)
                    nodeUpdater(terminal)
                    currSize = currSize + true_numberofnodes(terminal)
                else # Let's put another intermediate node and queue its children

                    f = fSet[Random.rand(1:end)]
                    subtree = InternalNode(f, Array{AbstractNode}(undef, f.arity))
                    nodeUpdater(subtree)

                    for i in 1:subtree.func.arity 
                        push!(randQueue, (x -> subtree.children[i] = x, nodeDepth+1))
                    end

                    currSize = currSize + 1
                end
            end
        end

        # Filling in who may have not all children after reaching the maximum
        # size limit
        while size(randQueue)[1] > 0
            let randNode = Random.rand(1:size(randQueue)[1])
                nodeUpdater, nodeDepth = randQueue[randNode]
                deleteat!(randQueue, randNode)

                nodeUpdater(_create_random_terminal(tSet))
            end
        end
    end

    return root
end


"""Function that initializes a population of size ```popSize``` using the
_grow_ method.

    init_pop_grow(
        fSet::Vector{Func}, 
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
        minDepth::Int64,
        maxDepth::Int64,
        expctdSize::Int64,
        popSize::Int64)::Vector{AbstractNode}

Every initialization functions take the same parameters, but not all do of them
makes use of all parameters. This is just to unify the call of initialization
functions.
"""
function init_pop_grow(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    minDepth::Int64,
    maxDepth::Int64,
    expctdSize::Int64,
    popSize::Int64)::Vector{AbstractNode}

    return AbstractNode[grow(fSet, tSet, maxDepth) for _ in 1:popSize]
end


"""Function that initializes a population of size ```popSize``` using the
_full_ method.


    init_pop_full(
        fSet::Vector{Func}, 
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
        minDepth::Int64,
        maxDepth::Int64,
        expctdSize::Int64,
        popSize::Int64)::Vector{AbstractNode}

Every initialization functions take the same parameters, but not all do of them
makes use of all parameters. This is just to unify the call of initialization
functions.
"""
function init_pop_full(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    minDepth::Int64,
    maxDepth::Int64,
    expctdSize::Int64,
    popSize::Int64)::Vector{AbstractNode}

    return AbstractNode[full(fSet, tSet, maxDepth) for _ in 1:popSize]
end


"""Function that initializes a population of size ```popSize``` using the
_ramped half-half_ method.


    init_pop_ramped(
        fSet::Vector{Func}, 
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
        minDepth::Int64,
        maxDepth::Int64,
        expctdSize::Int64,
        popSize::Int64)

Every initialization functions take the same parameters, but not all do of them
makes use of all parameters. This is just to unify the call of initialization
functions.
"""
function init_pop_ramped(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    minDepth::Int64,
    maxDepth::Int64,
    expctdSize::Int64,
    popSize::Int64)::Vector{AbstractNode}

    if popSize <= 0
        return AbstractNode[]
    end

    _range = maxDepth - minDepth + 1
    n      = popSize ÷ _range # divisão inteira
    q, r   = n÷2, n%2 

    treesFull = init_pop_full(fSet, tSet, 1, minDepth, expctdSize, q)
    treesGrow = init_pop_grow(fSet, tSet, 1, minDepth, expctdSize, q+r)
    trees     = init_pop_ramped(fSet, tSet, minDepth+1, maxDepth, expctdSize, popSize-n)

    return vcat(treesFull, treesGrow, trees)
end


"""Function that initializes a population of size ```popSize``` using the
_PTC2_ method.

    init_pop_PTC2(
        fSet::Vector{Func}, 
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
        minDepth::Int64,
        maxDepth::Int64,
        expctdSize::Int64,
        popSize::Int64)::Vector{AbstractNode}

Every initialization functions take the same parameters, but not all do of them
makes use of all parameters. This is just to unify the call of initialization
functions.
"""
function init_pop_PTC2(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    minDepth::Int64,
    maxDepth::Int64,
    expctdSize::Int64,
    popSize::Int64)::Vector{AbstractNode}
    
    return vcat([
        [PTC2(fSet, tSet, maxDepth, r) for _ in 1:(popSize ÷ expctdSize)]
        for r in 1:expctdSize
    ]...)
end