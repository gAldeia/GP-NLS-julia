# Author:  Guilherme Aldeia
# Contact: guilherme.aldeia@ufabc.edu.br
# Version: 1.0.0
# Last modified: 13-11-2021 by Guilherme Aldeia


"""Function that receives two individuals and makes a simple tournament
selection. An individual is a ```(fitness::Float64, node::AbstractNode)```
tuple with the tree and it fitness, to avoid recalculations all the time.

    tourn_selection(
        ind1::Tuple{Float64, AbstractNode},
        ind2::Tuple{Float64, AbstractNode})::Tuple{AbstractNode, Float64}

The return type is a tuple with the winning individual(that is, the 
individual winner tuple is returned).
"""
function tourn_selection(
    ind1::Tuple{AbstractNode, Float64}, ind2::Tuple{AbstractNode, Float64})

    _, fitness1 = ind1
    _, fitness2 = ind2
    
    return fitness1 < fitness2 ? ind1 : ind2
end


"""Crossover function that does a recombination of the two parents passed as an
argument, finding a breakpoint in each of the parent trees and swapping the
subtree between those breakpoints. It doesn't change the parents. This crossover
controls the number of nodes (not the depth) of the tree, avoiding to 
exceed the maximum value.

    crossover(
        fst_parent::AbstractNode,
        snd_parent::AbstractNode,
        maxDepth::Int64,
        maxSize::Int64)::AbstractNode
"""
function crossover(
    fst_parent::AbstractNode, snd_parent::AbstractNode,
    maxDepth::Int64, maxSize::Int64)::AbstractNode

    # first we take any cutoff point on the first tree
    child = copy_tree(fst_parent)
    child_point = Random.rand(1:numberofnodes(child))

    # We set the maximum allowable size to (maximum size - partial tree size)
    # (partial tree size would be the size of the tree minus size of the branch
    # that will be removed on crossover). Let's use the real number of nodes.
    partialSize = true_numberofnodes(fst_parent) - true_numberofnodes(get_branch_at(child_point, fst_parent))
    
    # we use max since the trees can exceed the size by a few units due to PTC2
    allowedSize = max(maxSize - partialSize, 1)

    # The same also goes for depth
    allowedDepth = max(maxDepth - get_depth_at(child_point, fst_parent), 1)

    # We find all subtrees in the second parent that are not larger than the
    # remaining allowed size.
    candidates, _ = branches_in_limits(allowedSize, allowedDepth, snd_parent)
    
    if length(candidates) == 0
        return child
    end

    # We randomly select one and swap it, creating a new child
    branch_point = candidates[Random.rand(1:end)]
    branch = copy_tree(get_branch_at(branch_point, snd_parent))

    return change_at!(child_point, branch, child)
end


"""Function that implements a traditional substitution mutation in a tree,
respecting the maximum past depth. __Modifies the tree passed__.

    mutation!(
        node::AbstractNode,
        maxDepth::Int64,
        maxSize::Int64,
        fSet::Vector{Func},
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}},
        mutationRate::Float64)::AbstractNode

The ```mutationRate``` mutation rate should vary by ``[0, 1]`` and determines
the chance of occurring a mutation (replacing a random point with a new
subtree). If no mutation is performed, then the given node is returned.
"""
function mutation!(
    node::AbstractNode,
    maxDepth::Int64,
    maxSize::Int64,
    fSet::Vector{Func},
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}},
    mutationRate::Float64)::AbstractNode
    
    if Random.rand() >= mutationRate
        return node
    end

    point = Random.rand(1:numberofnodes(node))
    
    # 'expected size' is somewhere between allowed and maximum sizes,
    # drawn at random
    randVal    = Random.rand()
    range      = maxSize - true_numberofnodes(get_branch_at(point, node))
    expctdSize = floor(Int64, randVal*range) + true_numberofnodes(get_branch_at(point, node))

    allowedDepth = maxDepth - (get_depth_at(point, node))

    random_branch = PTC2(fSet, tSet, allowedDepth, expctdSize)
    
    return change_at!(point, random_branch, node)
end


"""GP With depth and number of nodes control. The recommended startup is
PTC2, but we have the others as well (however, the other methods are based
in the koza GP and do not follow restrictions on the maximum number of nodes).
To use canonic GP, just disable ```lm_optimization``` and choose one of 
```["ramped", "grow", "full"]``` initializations. To use GP-NLS, turn on 
```lm_optimization``` and use ```"PTC2"``` as initialization method.

    GP(
        X::Matrix{Float64}, 
        y::Vector{Float64},
        fSet::Vector{Func},
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}};
        minDepth::Int64        = 1,
        maxDepth::Int64        = 5,
        maxSize::Int64         = 25,
        popSize::Int64         = 50,
        gens::Int64            = 50,
        mutationRate::Float64  = 0.25,
        elitism::Bool          = false,
        verbose::Bool          = false,
        init_method::String    = "PTC2", #["ramped", "grow", "full", "PTC2"]
        lm_optimization        = false, 
        keep_linear_transf_box = false
    )::AbstractNode

"""
function GP(
    X::Matrix{Float64}, 
    y::Vector{Float64},
    fSet::Vector{Func},
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}};
    minDepth::Int64        = 1,
    maxDepth::Int64        = 5,
    maxSize::Int64         = 25,
    popSize::Int64         = 50,
    gens::Int64            = 50,
    mutationRate::Float64  = 0.25,
    elitism::Bool          = false,
    verbose::Bool          = false,
    init_method::String    = "PTC2", #["ramped", "grow", "full", "PTC2"]
    lm_optimization        = false, 
    keep_linear_transf_box = false)::AbstractNode

    # Function to rollback zip, will be useful with tournament
    unzip(a) = map(x->getfield.(a, x), fieldnames(eltype(a)))

    # First let's initialize the population and do the first fit
    population = eval(Symbol("init_pop_$(init_method)"))(
        fSet, tSet, minDepth, maxDepth, maxSize, popSize)

    # The optimization step comes before calculating fitness
    if lm_optimization
        population = AbstractNode[
            apply_local_opt(p, X, y, keep_linear_transf_box) for p in population]
    end

    # Let's calculate and take the fitness of the entire population
    fitnesses = [fitness(p, X, y) for p in population]

    if verbose
        println("\nGer,\t smlstFit,\t LargestNofNodes,\t LargestDepth")
    end

    bestSoFar, bestFitness = nothing, nothing
    for g in 1:gens
        
        # At the beginning of the generation, we have the population and the
        # fitness. let's assemble the individuals
        finites     = isfinite.(fitnesses) # máscara com apenas fitness finitos
        individuals = collect(zip(population[finites], fitnesses[finites]))
        
        # Getting the best of the population before genetic operations
        if elitism
            bestSoFar, bestFitness = individuals[argmin(fitnesses[finites])]
            bestSoFar = copy_tree(bestSoFar)
        end

        if verbose
            # Getting information to print
            i1 = minimum(filter(isfinite, fitnesses))
            i2 = maximum([true_numberofnodes(p) for p in population[finites]])
            i3 = maximum([true_depth(p) for p in population[finites]])
            
            println("$g,\t $(i1),\t $(i2),\t $(i3)")
        end

        # Selecting parents for crossover
        parents, fitnesses = unzip(Tuple{AbstractNode, Float64}[
            tourn_selection(
                individuals[Random.rand(1:end)], 
                individuals[Random.rand(1:end)]
            ) for _ in 1:popSize])       
        
        # at crossover and mutation time, we want to take the nodes out of the
        # linear transformation when using the GP_NLS.
        # Let's take it out here before doing these operations, because at the
        # end of the generation they will be added and optimized again, and the
        # fitness is updated.
        
        # Applying crossover. (crossover returns copy, mutation modifies reference)
        children = if lm_optimization && keep_linear_transf_box
            # We know the node where the original tree is. Let's create a copy to not
            # change the original subtree (but we will keep reference to the 
            # originals for selection)
            AbstractNode[
                crossover(
                    parents[Random.rand(1:end)].children[1].children[1],
                    parents[Random.rand(1:end)].children[1].children[1],
                    maxDepth,
                    maxSize
                ) for _ in 1:popSize]
        else
            AbstractNode[
                crossover(
                    parents[Random.rand(1:end)],
                    parents[Random.rand(1:end)],
                    maxDepth,
                    maxSize
                ) for _ in 1:popSize]
        end

        # Crossover generates copies, we can modify with the mutation here
        children = AbstractNode[
            mutation!(c, maxDepth, maxSize, fSet, tSet, mutationRate) for c in children]
        
        # The optimization step comes before calculating fitness,
        # being applyed only for the children now
        if lm_optimization
            children = AbstractNode[
                apply_local_opt(c, X, y, keep_linear_transf_box) for c in children]
        end

        # Tournament for the next generation. We already have the parents'
        # fitness calculated, we need to calculate only half more
        fitnesses   = vcat(fitnesses, [fitness(c, X, y) for c in children])
        
        finites     = isfinite.(fitnesses) 
        individuals = collect(zip( vcat(parents, children)[finites], fitnesses[finites] ))
        
        population, fitnesses = unzip(Tuple{AbstractNode, Float64}[
            tourn_selection(
                individuals[Random.rand(1:end)], individuals[Random.rand(1:end)]
            ) for _ in 1:popSize])

        if elitism # Let's add one more to the population.
            push!(population, bestSoFar)
            push!(fitnesses, bestFitness)
        end
    end
    
    return population[argmin([fitness(p, X, y) for p in population])]
end