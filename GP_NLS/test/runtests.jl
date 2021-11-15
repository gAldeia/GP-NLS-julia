# Author:  Guilherme Aldeia
# Contact: guilherme.aldeia@ufabc.edu.br
# Version: 1.0.0
# Last modified: 15-11-2021 by Guilherme Aldeia


using Test

using LinearAlgebra
using LsqFit
using Random
using LinearAlgebra
using Statistics

using GP_NLS


# Various checks are unnecessary because of compiler type checking.


@testset "Testing NodeContent.jl" begin
    @testset "Function nodes" begin
        a = Float64[1., 2., 3.]

        for f in defaultFunctionSet
            # Test if we only have functions within the default set
            @test typeof(f) == Func

            # Test whether it takes one (or more) vector(s) and returns a single vector
            @test typeof(f.func([a for _ in 1:f.arity]...)) == Vector{Float64}
        end
    end

    @testset "Constant creation with ERC" begin
        # see if it always generates in the range
        for i in [1.0, 10.0, 100.0]
            aux_ERC = ERC(-i, i)
            for _ in 1:10000
                randVal = Random.rand()*(aux_ERC.u_bound - aux_ERC.l_bound) + aux_ERC.l_bound
                @test -i <= randVal < i
            end
        end
    end

    # Constant nodes are simple, and variable nodes too --- they are just structs
    # to store values. The ones that were tested involve calculations that
    # can lead to hard-to-find bugs in the code.
end


@testset "Testing TreeStructure.jl" begin
    # Testing subtypes
    @test typeof(GP_NLS.InternalNode) == typeof(GP_NLS.AbstractNode)
    @test typeof(GP_NLS.TerminalNode) == typeof(GP_NLS.AbstractNode)
    @test typeof(GP_NLS.AbstractNode) == typeof(GP_NLS.AbstractNode)
end


# Let's create a simple tree and a toy dataset
myprod = GP_NLS.myprod

# Let's create these separate for testing only constants and variables
x1 = GP_NLS.TerminalNode(Var("x1", 1))
c1 = GP_NLS.TerminalNode(Const(1.0))

test_tree = GP_NLS.InternalNode(Func(-, 2), [
    GP_NLS.InternalNode(Func(myprod, 2), [
        x1,
        c1
    ]),
    GP_NLS.InternalNode(Func(myprod, 2), [
        GP_NLS.TerminalNode(Const(-1.0)),
        GP_NLS.TerminalNode(Var("x2", 2))
    ])
])

toy_X = [
    1.  1.;
    2.  2.;
   -1. -1.;
   -2. -2.
]

toy_y = 1.25*toy_X[:, 1] - -1.25*toy_X[:, 2]


@testset "Testing Utils.jl" begin    
    #Test evaluate on a toy dataset
    @testset "Evaluate vectorization" begin
        @test evaluate(test_tree, toy_X) == [2., 4., -2., -4.]
        
        # It must always receive an array. In the case of vector, we need the reshape
        @test evaluate(test_tree, reshape(toy_X[1,:], (1, length(toy_X[1,:])))) == [2.] 
        
        # Evaluation of a constant must return a vector with same number of observations
        @test evaluate(c1, toy_X) == repeat([c1.terminal.value], size(toy_X, 1))

        # Evaluate on variable must return the column of the variable
        @test evaluate(x1, toy_X) == toy_X[:, 1]
    end
    
    @testset "Tree copy" begin
        # Get string reference from original tree
        test_tree_str  = getstring(test_tree)
        test_tree_copy = GP_NLS.copy_tree(test_tree)

        # Changing the children (struct is immutable, but list can have modified elements)
        test_tree_copy.children[1] = x1

        # Seeing if the reference still returns the same string (it should)
        @test test_tree_str == getstring(test_tree)

        # Seeing that the modified copy is different of the original
        @test test_tree_str != getstring(test_tree_copy)

        # Let's save the copied tree string and modify it again,
        # putting the original tree as a branch on it
        test_tree_copy_str = getstring(test_tree_copy)
        test_tree_copy.children[2] = test_tree

        @test test_tree_copy_str != getstring(test_tree_copy)
        @test test_tree_str != getstring(test_tree_copy)

        # Original must not have been affected either.
        @test test_tree_str == getstring(test_tree)
    end

    @testset "Traversing trees" begin
        #Which children: should work without error if p <= number of nodes
        for i in 1:(numberofnodes(test_tree)-1) # subtract 1 because it's the children without considering it
            @test typeof(GP_NLS.which_children(i, test_tree.children)) <:
                  Tuple{Integer, GP_NLS.AbstractNode}
        end
        
        # Get branch, should work like above
        for i in 1:(numberofnodes(test_tree)-1) # subtract 1 because it's the children without considering it
            @test typeof(GP_NLS.get_branch_at(i, test_tree)) <:
                  GP_NLS.AbstractNode
        end
    end

    # Testing changeat and change_children
    @testset "Modifying subtrees" begin
        # Create two copies of sample_tree and make one a subtree of the other
        test_tree_1 = GP_NLS.copy_tree(test_tree)
        test_tree_2 = GP_NLS.copy_tree(test_tree)
        
        # Let's see if the original references remain the same
        test_tree_1_str = getstring(test_tree_1)
        test_tree_2_str = getstring(test_tree_2)

        @test test_tree_1_str == test_tree_2_str

        # Let's change a node at maximum depth, we know it will use there
        # both change_children and change_at functions
        test_tree_changed = GP_NLS.change_at!(
            numberofnodes(test_tree_1)-1,
            test_tree_1,
            test_tree_2
        )

        # Let's go through the new tree to see if it didn't come broken
        for i in 1:(numberofnodes(test_tree_changed)-1) # subtract 1 because it's the children without considering it
            @test typeof(GP_NLS.get_branch_at(i, test_tree_changed)) <:
                  GP_NLS.AbstractNode
        end

        # Seeing if references have changed
        @test test_tree_1_str == test_tree_2_str
        @test test_tree_1_str == getstring(test_tree_1)
        @test test_tree_2_str == getstring(test_tree_2)

        # Let's see if changes to the new tree modify the originals
        test_tree_changed_str = getstring(test_tree_changed)
        test_tree_changed.children[1] = test_tree_1
        test_tree_changed.children[2] = test_tree_2

        @test test_tree_1_str == test_tree_2_str
        @test test_tree_1_str == getstring(test_tree_1)
        @test test_tree_2_str == getstring(test_tree_2)

        @test test_tree_changed_str != getstring(test_tree_changed)
    end

    # depth and numberofnodes are very simple, will not be tested
end


@testset "Testing LsqOptimization.jl" begin
    # Test find_const_nodes (here we know how many nodes there are)
    test_tree_lsq     = GP_NLS.copy_tree(test_tree)
    test_tree_lsq_str = getstring(test_tree_lsq)

    @testset "Finding constant nodes" begin
        const_nodes = GP_NLS.find_const_nodes(test_tree_lsq)
        @test const_nodes[1].terminal.value == 1.0
        @test const_nodes[2].terminal.value == -1.0
    end

    @testset "Replacing consts with new values" begin
        # Testing replace
        test_tree_replace = GP_NLS.replace_const_nodes(
            test_tree_lsq, [2.0, -2.0]
        )

        @test "-(myprod(x1, 2.0), myprod(-2.0, x2))" == getstring(test_tree_replace)

        # Seeing if the original reference is still intact (should)
        @test getstring(test_tree_lsq) == test_tree_lsq_str
    end

    # Test adapte (check if number of nodes, and if you have 2 more consts, and 
    # dedpth also increased)
    @testset "Tree adaptation" begin
        test_tree_H, test_tree_p0, test_tree_adapted = GP_NLS.adaptate_tree(test_tree)

        @test numberofnodes(test_tree_adapted) == numberofnodes(test_tree) + 4
        @test depth(test_tree_adapted) == depth(test_tree) + 2
    end
end


@testset "Evolutionary algorithm functions" begin
    # Using the default sets for these tests. NOTE: it is important to pay
    # attention in the type of terminals: even if we don't use all the
    # symbols, the expected array is of type Union{Var, Const, ERC}.
    fSet = defaultFunctionSet

    tSet = Vector{Union{Var, WeightedVar, Const, ERC}}(vcat(
        defaultConstSet,
        defaultERCSet,
        Var[Var("x$(i)", i) for i in 1:2],
        WeightedVar[WeightedVar("x$(i)", i) for i in 1:2]
    ))
    
    @testset "PTC2 Initialization" begin  
        random_pop = GP_NLS.init_pop_PTC2(fSet, tSet, 1, 10, 10, 5000)

        @test size(random_pop, 1) == 5000

        # check if they respect restrictions (and if it was possible to traverse
        # the tree without error)          
        for p in random_pop
            # PTC2 guarantees a maximum of 1 depth beyond maximum allowed
            @test 1 <= depth(p) <= 10 + 1

            # PTC2 guarantees that it will have at most the greatest arity of
            # the functions beyond maximum allowed
            @test 1 <= numberofnodes(p) <= 50 + 2
        end        
    end

    @testset "Ramped half-half initialization" begin  
        random_pop = GP_NLS.init_pop_ramped(fSet, tSet, 1, 5, 10, 5000)

        @test size(random_pop, 1) == 5000

        # check if they respect restrictions (and if it was possible to traverse
        # the tree without error)            
        for p in random_pop

            @test 1 <= depth(p) <= 5 + 1
            @test 1 <= numberofnodes(p) <= 50 + 2
        end        
    end

    # Let's generate a ramped halfhalf pop for the rest of the tests 
    random_pop = GP_NLS.init_pop_ramped(fSet, tSet, 1, 5, 10, 5000)

    # Saving strings from initial population to later compare
    # with new trees generated by crossover and mutation
    random_pop_strs = [getstring(p) for p in random_pop]

    @testset "Initial population to test mutation and crossover" begin 
        @test size(random_pop, 1) == 5000

        for p in random_pop
            @test 1 <= depth(p) <= 5
            @test 1 <= numberofnodes(p) <= 2^5
        end        
    end

    @testset "Fitness evaluation" begin
        for p in random_pop# Test fitness of an expression in the toy dataset
            @test typeof(fitness(p, toy_X, toy_y)) <: Real 

            # Test with NaN values
            @test fitness(p, toy_X, [NaN, 1.0, 1.0, 1.0]) == Inf

            # Test with inf values
            @test fitness(p, toy_X, [1.0, 1.0, Inf, 1.0]) == Inf
        end
    end

    @testset "Crossover" begin
        children = [
            GP_NLS.crossover(
                random_pop[Random.rand(1:end)],
                random_pop[Random.rand(1:end)],
                5,
                2^5
            ) for _ in 1:5000]

        # See if they respect restrictions (and if it is possible to
        # traverse the tree without error)
        for c in children
            @test 1 <= depth(c) <= 5
            @test typeof(fitness(c, toy_X, toy_y)) <: Real
        end

        # See if original reference is changed
        for (p, p_str) in zip(random_pop, random_pop_strs)
            @test getstring(p) == p_str 
        end
    end

    @testset "Mutation" begin
        children = [
            GP_NLS.mutation!(
                random_pop[i],
                5,              # Maximum allowed depth
                2^5,            # Maximum number of nodes allowed
                fSet,
                tSet,
                1.0
            ) for i in 1:5000]

        # See if they respect restrictions (and if it is possible to
        # traverse the tree without error)
        for c in children
            @test 1 <= depth(c) <= 6 # PTC2 has a chance of creating a tree with (max depth + 1)
            @test typeof(fitness(c, toy_X, toy_y)) <: Real
        end

        # See if original reference is changed
        for (p, p_str) in zip(random_pop, random_pop_strs)
            @test getstring(p) == p_str 
        end
    end
end