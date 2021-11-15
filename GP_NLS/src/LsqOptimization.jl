# Author:  Guilherme Aldeia
# Contact: guilherme.aldeia@ufabc.edu.br
# Version: 1.0.0
# Last modified: 15-11-2021 by Guilherme Aldeia


"""Function that takes a node of a tree (```AbstractNode```) and traverses it
recursively, looking for all terminal nodes that have as content a ```Const```
or a ```WeightedVar```. This function makes internal use of a list of nodes
```Vector{AbstractNode}```, which is passed by reference to the calls
recursively. The recursive calls will add a reference to the nodes found
in this list.

    find_const_nodes(
        node::AbstractNode, nodes=Vector{AbstractNode}())::Vector{TerminalNode}

This function is for the internal use of the package, and is used in the
optimization method.
"""
function find_const_nodes(
    node::AbstractNode, nodes=Vector{AbstractNode}())::Vector{TerminalNode}
    
    if typeof(node) == TerminalNode
        if typeof(node.terminal) == Const || typeof(node.terminal) == WeightedVar
            push!(nodes, node)
        end
    else
        map(node.children) do child
            find_const_nodes(child, nodes)
        end
    end
    
    return nodes
end


"""Function that takes a node of a tree (```AbstractNode```) and a vector
of type ```theta::Vector{Float64}``` with the same number of elements as the
number of constants from the given tree, and recursively replaces the constants
of the tree. This is the update step of the GP-NLS algorithm, where we take new
vales for the constants and replace them in the original tree with the elements
of ```theta```. This function does not change the arguments passed, and returns
a new tree.
    
The ```theta``` must have the same number of the total count of ```Const``` and
```WeightedVar``` nodes in the tree.

    replace_const_nodes(
        node::AbstractNode, theta::Vector{Float64}, _first_of_stack=true)::AbstractNode

The ```_first_of_stack``` argument is for internal use of the function. It is
used to create a copy of ```theta``` where is safe to remove elements without
changing the original vector.

This function is for the internal use of the package, and is used in the
optimization method.
"""
function replace_const_nodes(
    node::AbstractNode, theta::Vector{Float64}, _first_of_stack=true)::AbstractNode

    if _first_of_stack
        theta = copy(theta)
    end
        
    if typeof(node) == TerminalNode
        if typeof(node.terminal) == Const
            
            new_value = theta[1]
            
            popfirst!(theta)
            
            return TerminalNode(Const(new_value))
        elseif typeof(node.terminal) == WeightedVar
            new_value = theta[1]
            
            popfirst!(theta)
            
            return TerminalNode(WeightedVar(
                node.terminal.var_name, node.terminal.var_idx, new_value))        
        else
            return TerminalNode(node.terminal)
        end
    else
        f = node.func
        
        children = AbstractNode[
            replace_const_nodes(c, theta, false) for c in node.children]
        
        return InternalNode(f, children)
    end
end


"""Function that evaluates the tree simulating that the constants were replaced
by the ```theta``` values. The idea is to simulate the replacement without the
need of completely rebuild the tree, aiming to reduce the computational cost
when the optimization method performs many iterations.

    evaluate_replacing_consts(
        node::Union{TerminalNode, InternalNode}, X::Matrix{Float64},
        theta::Vector{Float64}, c_idx::Int64=0)::Tuple{Vector{Float64}, Int64}

The ```c_idx``` variable is used internally to keep track of the indexes
of ```theta``` that have already been used or not, so that the replacement
simulation is done correctly.

This function is for the internal use of the package, and is used in the
optimization method. Implements multiple dispatch.    
"""
function evaluate_replacing_consts(
    node::TerminalNode, X::Matrix{Float64},
    theta::Vector{Float64}, c_idx::Int64=0)::Tuple{Vector{Float64}, Int64}

    if typeof(node.terminal) == Var
        return X[:, node.terminal.var_idx], c_idx
    elseif typeof(node.terminal) == WeightedVar
        c_idx += 1
        return X[:, node.terminal.var_idx].*theta[c_idx], c_idx
    else
        c_idx += 1
        return ones(size(X,1)) * theta[c_idx], c_idx
    end
end

function evaluate_replacing_consts(
    node::InternalNode, X::Matrix{Float64},
    theta::Vector{Float64}, c_idx::Int64=0)::Tuple{Vector{Float64}, Int64}
    
    args = map(node.children[1:node.func.arity]) do child
        evaluated, c_idx = evaluate_replacing_consts(child, X, theta, c_idx)
        evaluated
    end

    return node.func.func(args...), c_idx
end


# Let's create constant functions that we know are needed for adaptation
# used in the optimization process. Those correspond to the offset and scale
# nodes of the GP-NLS
const adapt_sum  = Func(+, 2)
const adapt_prod = Func(myprod, 2)


"""Function that receives a tree and makes the necessary adaptations to be
able to apply the optimization with the nonlinear least squares method.
Does not modify the arguments. Returns a function that receives ```X``` and
```theta``` to perform tree evaluation, the initial ```theta``` vector (which
corresponds to the original coefficients of the tree before the optimization
process), and the adapted tree.

    adaptate_tree(node::AbstractNode)::Tuple{Function, Vector{Float64}, AbstractNode}

The adaptation is done by adding 4 new nodes in the tree, to create the linear
transformation box (it adds an intercept and a slope to the tree). This function
The returned function takes as arguments ```X::Matrix{Float64}``` and
```theta::Vector{Float64}``` to perform the evaluation (```evaluate```). The
```H``` function returned is internally used in an autodiff algorithm to obtain
the Jacobian in the optimization method.

This function is for the internal use of the package, and is used in the
    optimization method.
"""
function adaptate_tree(node::AbstractNode)::Tuple{Function, Vector{Float64}, AbstractNode}
    
    # Placeholder of the intercept and slope will be 1.0. Let's add the nodes:
    with_scaling = InternalNode(adapt_prod, [node, TerminalNode(Const(1.0))])
    with_offset  = InternalNode(adapt_sum, [with_scaling, TerminalNode(Const(1.0))])
    
    # Finding the constants and creating the initial theta vector
    const_nodes = find_const_nodes(with_offset)

    p0 = [typeof(c.terminal) == Const ? c.terminal.value : c.terminal.weight for c in const_nodes]
    
    return (
        (X, theta) -> evaluate_replacing_consts(with_offset, X, theta)[1],
        p0,
        with_offset
    )
end


"""Function that receives a node of a tree (```AbstractNode```), an array with
the ```X::Matrix{Float64}``` training data, and an array with expected values
```y::Vector{Float64}```, and applies the optimization process of non-linear
least squares. Returns an adjusted tree.

    apply_local_opt(
        node::AbstractNode, X::Matrix{Float64},
        y::Vector{Float64}, keep_linear_transf_box=false)::AbstractNode

We can choose to return the expression with/without the transformation box.
In case it is returned, it is worth noting that the code will not apply
mutation or crossover at the nodes of the block.

This function is for the internal use of the package, and is used in the
    optimization method.
"""
function apply_local_opt(
    node::AbstractNode, X::Matrix{Float64},
    y::Vector{Float64}, keep_linear_transf_box=false)
    
    node_H, node_p0, node_adapted = adaptate_tree(node)
    
    # Use multiple 1's as a starting point for optimization (instead of 
    # original values)
    #node_p0 = ones(size(node_p0, 1))

    try
        # autodiff have different modes: ["forwarddiff", "finiteforward"]
        # (default is _finite differences_, this works fine most of the time)
        fit = curve_fit(
            node_H,
            X,
            y,
            node_p0,
            maxIter=10,
            autodiff=:finiteforward 
        )
        
        theta = fit.param
        
        node_optimized = replace_const_nodes(node_adapted, theta)

        if keep_linear_transf_box
            return node_optimized
        else
            return node_optimized.children[1].children[1]
        end
    catch err
        # we may have errors in the automatic differentiation if the tree
        # derivatives are not continuous in some point.
        # Let's return the function without adjusting the coefficients then.

        print(err)
        if keep_linear_transf_box
            return node_adapted
        else
            return node_adapted.children[1].children[1]
        end
    end
end