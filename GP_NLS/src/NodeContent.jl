# Author:  Guilherme Aldeia
# Contact: guilherme.aldeia@ufabc.edu.br
# Version: 1.0.0
# Last modified: 13-11-2021 by Guilherme Aldeia


"""_Struct_ to be the content of an internal node of an expression tree.

    Func(f::Function, a::Int64)

Takes a function ```f``` and the arity ```a``` of the function. The function
must always work in vectorized form (will always receive ``a`` arrays with
``n`` values, where each value of the array is an observation). So the function
input will have ```a``` rows and ```n``` columns when this node is being
evaluated in other methods.

The function's representation as a _string_ is inferred from the name of the
function passed, and when this node is used to create a node of a tree,
it will have ``a`` children.

When creating new functions, protected operators must not be used. The 
non-linear optimization method uses autodiff to differentiate the tree, and
complex functions can be problematic to automatically differentiate.
"""
struct Func
    func    :: Function
    arity   :: Int64
    str_rep :: String

    Func(f::Function, a::Int64) = new(f, a, string(f))
end


"""_Struct_ to be the content of an terminal node of an expression tree. This
struct represents a Float64 constant value.

    Const(v::Float64)

Receives a Float64 value ```v``` which will be used as a constant.

The representation of the constant as _string_ is obtained by rounding the
value to 3 decimal places, and it is automatically obtained.

When using non-linear optimization, the nonlinear least squares optimization
method looks for this _struct_ specifically to optimize their values.
"""
struct Const
    value   :: Float64
    str_rep :: String

    Const(v:: Float64) = new(v, string(round(v, digits=3)))
end


"""_Struct_ to be the content of an terminal node of an expression tree. This
struct keeps the range limits for creating a random constant with the ERC
method.
    
    ERC(lb::Float64, ub::Float64)

This _struct_ is used to create constants in the terminal nodes.
When it is selected to be a terminal, a new terminal will be created with the
_struct_ ```Const``` with a random value drawn between ```[lb, ub)``` to take
the place of the ERC (_Ephemeral Random Constant_) at the terminal node.
The _string_ representation of the created constant is as described in
```Const``` documentation.
"""
struct ERC
    l_bound :: Float64
    u_bound :: Float64
    
    ERC(lb::Float64, ub::Float64) = new(lb, ub)
end


"""_Struct_ to be the content of a terminal node of an expression tree. This
struct represents a variable of the data set.

    Var(v::String, i::Int64)

Receives a _string_ ```v``` that will be used as the representation of the
variable when printing the expression (you can use a _placeholder_ if the
database do not have column names) and a ```ì``` index that matches the
column index of the corresponding variable in the observations.
"""
struct Var
    var_name :: String
    var_idx  :: Int64
    str_rep  :: String

    Var(v::String, i::Int64) = new(v, i, v)
end


"""_Struct_ to be the content of a terminal node of an expression tree. This
struct represents a weighted variable, that have a coefficient associated with
it at the time of creation.

    WeightedVar(v::String, i::Int64)

This struct represents a weighted variable, that can be adjusted with 
the non-linear least squares method.

The _String_ representation is inferred as the same way when creating a ``Var``
and the coefficient is inferred in the same way as a ``Const``.

    WeightedVar(v::String, i::Int64, w::Float64)

Additionally, you can force a specific coefficient by passing the value
as the third argument on the constructor. When no value is specified, the
coefficient is set to 1.0.

This weighted variable is a subtree with 3 nodes and depth 2, but in practice
it is treated as a single node, as it is not of interest to make the
dissociation between the weight and the variable during the GP process.
By treating the weighted variable as a single node, it is not necessary to
modify the crossover or mutation implementations to prevent changing the
subtree.
"""
struct WeightedVar
    var_name :: String
    var_idx  :: Int64
    str_rep  :: String
    weight   :: Float64

    WeightedVar(v::String, i::Int64)             = new(v, i, "1.0*$(v)", 1.0)
    WeightedVar(v::String, i::Int64, w::Float64) = new(v, i, "$(round(w, digits=3))*$(v)", w)
end

    
# For ease of use and to serve as an example, some default sets will be provided.

# We declare it as const to prevent them from changing the value, and make it clear that they shouldn't.
const myprod(args...)    = args[1] .* args[2]
const mydiv(args...)     = args[1] ./ args[2] # Note that it is not protected division!
const mysin(args...)     = sin.(args[1])
const mycos(args...)     = cos.(args[1])
const mysqrtabs(args...) = sqrt.(abs.(args[1]))
const mysqrt(args...)    = sqrt.(args[1])
const mysquare(args...)  = args[1].^2
const myexp(args...)     = exp.(args[1])
const mylog(args...)     = log.(args[1])

#mysin(args) = sin.(args) # It would be possible to take only one argument if it's unary, but it's better to keep the default

"""Default functions set

    Func(+, 2),
    Func(-, 2),
    Func(myprod, 2),
    Func(mydiv, 2),

    Func(mysquare, 1),
    Func(mysqrt, 1),
    Func(myexp, 1),
    Func(mylog, 1)
"""
defaultFunctionSet = Func[ # Defining a set of standard functions (same as used in the original reference)
    Func(+, 2),
    Func(-, 2),
    Func(myprod, 2),
    Func(mydiv, 2),

    Func(mysquare, 1),
    Func(mysqrt, 1),
    Func(myexp, 1),
    Func(mylog, 1),

    #Func(mysin, 1),
    #Func(mycos, 1),
    #Func(mysqrtabs, 1),
]

"""Default const set

    Const(3.1415),
    Const(1.0),
    Const(-1.0)
"""
defaultConstSet = Const[
    Const(3.1415),
    Const(1.0),
    Const(-1.0)
]

"""Default ERC set

    ERC(-1.0, 1.0)

"""
defaultERCSet = ERC[
    ERC(-1.0, 1.0)
]