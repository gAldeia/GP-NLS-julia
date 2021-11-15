# Author:  Guilherme Aldeia
# Contact: guilherme.aldeia@ufabc.edu.br
# Version: 1.0.0
# Last modified: 13-11-2021 by Guilherme Aldeia


"""Function that takes any node of a tree (```AbstractNode```) and recursively
builds a _string_ representation of the tree, where functions are always denoted
in prefixed notation, with arguments in parentheses.

    getstring(node::AbstractNode)::String

This function works by having a multiple dispatch for each subtype of
```AbstractNode```.
"""
function getstring(node::TerminalNode)::String
        return node.terminal.str_rep
end

function getstring(node::InternalNode)::String
    child_str_rep = join([getstring(c) for c in node.children], ", ")

    return "$(node.func.str_rep)($(child_str_rep))"
end


"""Function that takes any node of a tree (```AbstractNode```) and recursively
recreates the structure so that references are not shared between the
tree passed and the tree returned, avoiding side effects when manipulating
the tree.

    copy_tree(node::AbstractNode)::TerminalNode

This function works by having a multiple dispatch for each subtype of
```AbstractNode```.
"""
function copy_tree(node::TerminalNode)::TerminalNode
    if typeof(node.terminal) == Var
        return TerminalNode(node.terminal)
    elseif typeof(node.terminal) == WeightedVar
        return TerminalNode(WeightedVar(
            node.terminal.var_name, node.terminal.var_idx, node.terminal.weight
        )) 
    else
        return TerminalNode(Const(node.terminal.value))
    end
end

function copy_tree(node::InternalNode)::InternalNode
    return InternalNode(node.func, [copy_tree(c) for c in node.children])
end


"""Function that takes any node of a tree (```AbstractNode```) and recursively
finds the depth of the tree, where the depth is the size of its largest branch.
This depth function does not take into count the coefficients of weighted
variables (which are, in fact, a subtree with depth 2). To find the depth
of a tree considering weighted variables as a subtree (and not as a single
node), use the function ```true_depth```.

    depth(node::AbstractNode)::Int64

This function works by having a multiple dispatch for each subtype of
```AbstractNode```.
"""
depth(node::TerminalNode)::Int64 = 1
depth(node::InternalNode)::Int64 = 1 + maximum([depth(c) for c in node.children])


"""Function that takes any node of a tree (```AbstractNode```) and recursively
finds the depth of the tree, where the depth is the size of its largest branch.
This depth function returns a value that corresponds to the number of existing
nodes in the tree, considering weighted variables as being a subtree of depth 2.
This function is not used in implementations, and is available to users who
want to get the real depth of GP-NLS trees.

    true_depth(node::AbstractNode)::Int64

This function works by having a multiple dispatch for each subtype of
```AbstractNode```.
"""
true_depth(node::TerminalNode)::Int64 = 1
true_depth(node::InternalNode)::Int64 = 1 + maximum([true_depth(c) for c in node.children])


"""Function that takes any node of a tree (```AbstractNode```) and recursively
counts the total number of nodes of the tree. This function counts weighted
variables as a single node. To find the number of nodes of a tree considering
weighted variables as a subtree (and not as a single node), use the function
```true_numberofnodes```.

    numberofnodes(node::AbstractNode)::Int64

This function works by having a multiple dispatch for each subtype of
```AbstractNode```.
"""
numberofnodes(node::TerminalNode)::Int64 = 1
numberofnodes(node::InternalNode)::Int64 = 1 + sum([numberofnodes(c) for c in node.children])


"""Function that takes any node of a tree (```AbstractNode```) and recursively
counts the total number of nodes of the tree. This function counts weighted 
variables as three nodes. This function is only used in mutate, crossover, and
initialize operations to avoid creating trees larger than the allowed.

    true_numberofnodes(node::AbstractNode)::Int64

This function works by having a multiple dispatch for each subtype of
```AbstractNode```.
"""
true_numberofnodes(node::TerminalNode)::Int64 = typeof(node.terminal) == WeightedVar ? 3 : 1
true_numberofnodes(node::InternalNode)::Int64 = 1 + sum([true_numberofnodes(c) for c in node.children])


"""Function that takes a set of children of the same node as the array
```children::Vector{AbstractNode}```, and an integer ```p``` (__which must be
less than or equal to number of nodes in ```children```__) and finds the child
containing the p-th node of the children if it was traversed inorder.

Returns a tuple containing the child which contains the node of index ```p```,
and an integer informing the position of the p-th node within the returned
(child) subtree.

    which_children(p::Int64, children::Vector{AbstractNode})::Tuple{Int64, AbstractNode}
"""
function which_children(
    p::Int64, children::Vector{AbstractNode})::Tuple{Int64, AbstractNode}

    if numberofnodes(children[1]) < p
        return which_children(p - numberofnodes(children[1]), children[2:end])
    else
        return (p, children[1])
    end
end


"""Function that takes any node of a tree (```AbstractNode```) and an integer
```p``` (__which must be less than or equal to the number of nodes in
```tree```__) and returns the branch at position ```p```.

    get_branch_at(p::Int64, node::AbstractNode)::AbstractNode
"""
function get_branch_at(p::Int64, node::AbstractNode)::AbstractNode

    if p <= 1
        return node
    else
        return get_branch_at(which_children(p-1, node.children)...)
    end
end


"""Function that takes a point ```p``` (__which must be less than or equal to
the number of nodes of ```branch```__), a branch of type ```AbstractNode```,
and a list of children ```Vector{AbstractNode}```.
Returns a modification of the list of children, where the ```p``` position node
will be replaced by the given branch. __This function changes the list of
children passed as argument__.

    change_children!(p::Int64, branch::AbstractNode, children::Vector{AbstractNode})::Vector{AbstractNode}

This function is a helper to ```change_at!```, and itsfor internal use.
It is not exported by the module.
"""
function change_children!(
    p::Int64, branch::AbstractNode, children::Vector{AbstractNode})::Vector{AbstractNode}

    if size(children, 1) == 0 
        return Vector{AbstractNode}(undef, 0)
    end

    # If the number of nodes in the first child is smaller than p, we know it's
    # not this child that's going to be modified. Let's go to the next
    if numberofnodes(children[1]) <= p
        return prepend!(
            change_children!(p-numberofnodes(children[1]), branch, children[2:end]),
            [children[1]]
        )
    else
        return prepend!(
            children[2:end],
            [change_at!(p, branch, children[1])]
        )
    end
end


"""Takes a point ```p``` of type integer (__which must be less than or equal
to the number of nodes of ```branch```__), a branch of type ```AbstractNode```,
and any node ```AbstractNode``` representing a tree.
Returns a modification of the tree by inserting the branch into the tree
at position ```p``. __This function changes the tree passed as argument__.

    change_at!(p::Int64, branch::AbstractNode, node::AbstractNode)::AbstractNode

This method is mainly used to modify trees in the _crossover_ operation.
"""
function change_at!(
    p::Int64, branch::AbstractNode, node::AbstractNode)::AbstractNode

    # If we are not at the point p, then it will be in some child of that
    # tree. Let's call change_children! in the list of children
    if p <= 1
        return branch
    else
        return InternalNode(node.func, change_children!(p-1, branch, node.children))
    end
end


"""Takes a point ```p``` of type integer (__which must be less than or equal
to the number of nodes of the ```node``` passed__) and any node
```AbstractNode``` representing a tree, then this function find and return
the depth of the subtree at position ```p```.

    get_depth_at(p::Int64, node::AbstractNode)::Int64

It's almost like finding the depth of the tree, but when we are interested 
in finding the depth of a subtree that is at the point ```p```, not the whole
tree depth.
"""
function get_depth_at(p::Int64, node::AbstractNode)::Int64
    if p <= 1
        return 1
    else
        return 1 + get_depth_at(which_children(p-1, node.children)...)
    end
end


"""Finds all branches of any tree ```node``` that have a number
of nodes less than or equal to ```allowedSize``` __and__ a depth less than or
equal to ```allowedDepth``` . Returns a list with the position of all
branches found.

    branches_in_limits(
        allowedSize::Int64, allowedDepth::Int64, node::AbstractNode, _point::Int64=1)::Vector{Int64}

The ```_point``` parameter being returned is for internal use, and serves to
monitor the point of the tree where the candidates were found. This is only
meaningful to recursive calls, and outside of the function it does not represent
any useful information.
"""
function branches_in_limits(
    allowedSize::Int64, allowedDepth::Int64, node::AbstractNode, _point::Int64=1)::Tuple{Vector{Int64}, Int64}
    
    found = Vector{Int64}(undef, 0)
    
    # First let's see if the node in question fits
    if true_numberofnodes(node) <= allowedSize && depth(node) <= allowedDepth
        push!(found, _point)
    end

    # If it has children, we need to recursively call
    if typeof(node) == InternalNode

        # We have to call the children passing the point they are in the tree
        for c in node.children
            child_found, _point = branches_in_limits(allowedSize, allowedDepth, c, _point+1)

            found = vcat(found, child_found)
        end
    end

    return found, _point
end