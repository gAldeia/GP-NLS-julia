# Unexported functions

The module has some built-in auxiliary functions that its external use is not
recommended. All implementations are listed in the modules of the
library, but only some functions are exported outside the package.

## Tree structural nodes

To build the expression trees, the defined _structs_ are used.
Those serves as the backbone of the tree, where every node has a different
content.

### Types and functions

```@autodocs
Modules = [GP_NLS]
Public  = false
Pages   = ["TreeStructure.jl"]
```

## Auxiliary functions

Implementation of some auxiliary functions that are used
to inspect and manipulate trees more generally.

### Types and functions

```@autodocs
Modules = [GP_NLS]
Public  = false
Pages   = ["Utils.jl"]
```

## Population Initialization

Implementation of different functions to initialize individual trees, as well 
as functions to create an entire population.

### Types and functions

```@autodocs
Modules = [GP_NLS]
Public  = false
Pages   = ["Initialization.jl"]
```

## Non-linear Least Squares optimization

Implementation of auxiliary functions and the nonlinear optimization method
of coefficients. All functions declared here are for internal use by
the module.

### Types and functions

```@autodocs
Modules = [GP_NLS]
Public  = false
Pages   = ["LsqOptimization.jl"]
```

## Genetic Programming algorithm

Mutation, crossover and GP implementation.

### Types and functions

```@autodocs
Modules = [GP_NLS]
Public  = false
Pages   = ["Evolutionary.jl"]
```
