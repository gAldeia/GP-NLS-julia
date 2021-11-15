# GP_NLS in Julia Documentation

Implementation of a Symbolic Regression Algorithm with the Tree Representation
and the possibility of using a non-linear optimization method to adjust the
coefficients of  the trees during the evolutionary process.

## About

TODO.

## Functions visible by import

The functions that are actually exported are listed below.

### Types

* [`Func`](@ref)
* [`Const`](@ref)
* [`Var`](@ref)
* [`WeightedVar`](@ref)
* [`ERC`](@ref)      
  
### Default sets

* [`defaultFunctionSet`](@ref)
* [`defaultConstSet`](@ref)
* [`defaultERCSet`](@ref)     

### Auxiliary functions

* [`evaluate`](@ref)
* [`getstring`](@ref)
* [`numberofnodes`](@ref)
* [`depth`](@ref)
* [`true_numberofnodes`](@ref)
* [`true_depth`](@ref)        

### Genetic Programming algorithm

* [`GP`](@ref)
* [`fitness`](@ref)
     

## All functions

The module has some built-in auxiliary functions that its external use is not
recommended. All implementations are listed in the modules of the
library, but only some functions are exported outside the package.