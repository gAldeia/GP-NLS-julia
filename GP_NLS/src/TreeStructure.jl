# Author:  Guilherme Aldeia
# Contact: guilherme.aldeia@ufabc.edu.br
# Version: 1.0.0
# Last modified: 13-11-2021 by Guilherme Aldeia


"""Abstract type of our symbolic tree nodes. The idea of creating this type is
to create subtypes ```InternalNode``` and ```TerminalNode```, and then
use multiple dispatch to implement functions that should have different
behavior when manipulating the expression trees.

Expression trees should not be built using
```Var, WeightedVar, Const, Func, ERC```, but with these nodes, which 
are intended to be used as the "backbone" of the tree. The backbone is build
using the ```InternalNode``` and ```TerminalNode```, and its contents should
be the ones declared in ``NodeContent.jl``.

A terminal node must have as its contents only the types
```Const, Var, WeightedVar```, and an internal nodemust have its contents the
type ```Func```.

Notice that the ERC, when selected to be used in a terminal
during the creation of a tree, is replaced by a random Const node). There are
not any explicit ERC terminal in the trees.
"""
abstract type AbstractNode end


"""_Struct_ to build the terminal nodes of the backbone of the tree.
Its contents will always be of the ```terminal``` type:
```Union{Const, Var, WeightedVar}```.

    TerminalNode(terminal::Union{Const, Var, WeightedVar}) <: AbstractNode
"""
struct TerminalNode <: AbstractNode
    terminal :: Union{Const, Var, WeightedVar}
end


"""_Struct_ to build the internal nodes of the backbone of the tree.
Its contents will always be of the ```func``` type, a ```f ::Func``` function
that will necessarily have ```f.arity``` children, where ```f.arity``` is the
arity of the function.

    InternalNode(f::Func, children::Vector{AbstractNode}) <: AbstractNode
"""
struct InternalNode <: AbstractNode
    func     :: Func
    children :: Vector{AbstractNode}
end