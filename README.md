# GP-NLS-julia

Julia implementation of the GP-NLS algorithm for symbolic regression described in the paper:

> [Kommenda, M., Burlacu, B., Kronberger, G. et al. Parameter identification for symbolic regression using nonlinear least squares. _Genet Program Evolvable_ _Mach_ 21, 471–501 (2020)](https://link.springer.com/article/10.1007/s10710-019-09371-3).

The
documentation of this package is available [here](https://galdeia.github.io/GP-NLS-julia/).

## What is Symbolic Regression?

<!--Hack for showing equations: https://gist.github.com/a-rodin/fef3f543412d6e1ec5b6cf55bf197d7b-->

Symbolic regression is the task of finding a good mathematical expression
to describe the relationship between a set of independent variables <img src="https://render.githubusercontent.com/render/math?math=\mathbf{X} = X_1, X_2, \ldots, X_n">
with a dependent variable <img src="https://render.githubusercontent.com/render/math?math=Y">, normally represented as tabular data:

In other words, suppose that you have available <img src="https://render.githubusercontent.com/render/math?math=m"> observations with <img src="https://render.githubusercontent.com/render/math?math=n"> variables, and a response variable that you supose that have a relationship <img src="https://render.githubusercontent.com/render/math?math=f(\mathbf{X}) = Y">, but the function <img src="https://render.githubusercontent.com/render/math?math=f"> is unknown: we can only see how the response changes when the input changes, but we don't know how the response is described by the variables of the problem. Symbolic regression tries to find a function <img src="https://render.githubusercontent.com/render/math?math=\widehat{f}"> that approximates the output of the unknown function just by learning mathematical structures from the data itself.

## How GP-NLS works

The idea behind the use of evolutionary algorithms is to manipulate a population of mathematical expressions computationally (represented using expression trees). A fitness function, which measures how good each expression is (this function could be, for example, the Mean Squared Error) the individuals of the population have their _fitness_ to represent how well each function describes the data. Through variation operations (which define the power of _exploration_ of the algorithm, done in the full search space, or the power of _exploration_, which performs a local search) and selective pressure (which promote the maintenance of good solutions in the population), a simulation of the evolutionary process tends to converge to good solutions present in the population. However, it is worth noting that there is no guarantee that the optimal solution will be found, although generally, the algorithm will return a good solution if possible.

The genetic programming algorithm starts with a random population of solutions, which are represented by trees, and then using a fitness function, it repeats the process of selecting the parents, performing the cross between them, applying a mutation on the child solutions, and, finally set a new generation choice between parents and children. This process is repeated until a stop criteria is met.

GP-NLS creates symbolic trees but expands them by adding an intercept, slope, and a coefficient to every variable. The new free parameters are then adjusted using the non-linear optimization method called Levenberg-Marquardt.

![GP-NLS tree example](./expanded_tree.jpg)

-----

The implementation is within folder ``./GeneticProgrammingNLS``. In ``./docs`` you can
find an automatically generated documentation for the package. In ``./experiments``
there are some scripts to evaluate the different ways of creating/optimizing
free parameters of the symbolic regression models, with results reported in
``./experiments/results`` and comparative plots in ``./experiments/plots``

## Installing:

inside the git root folder (which contains the implementation of GP-NLS for
symbolic regression) start a julia terminal and enter in the _pkg_ manager
environment by pressing ``]``. To add GP_NLS to your local packages:

```julia
dev ./GP_NLS
```

Now you can use the "original" GP as well as the GP with non-linear least 
squares optimization by importing it:

```julia
using GP_NLS
```

The first time you import, Julia wil precompile all files, this can take a while.

## Testing:

inside ``.GP-NLS`` folder (which contains the implementation of GP-NLS for
symbolic regression) start a julia terminal and enter in the _pkg_ manager
environment by pressing ``]``.

First you need to activate the local package:

```julia
activate .
```

Then you can run the tests:

```julia
test
```

### Building the docs:

You need to have ``Documenter``. First, install it using the package manager:

```julia
import Pkg; Pkg.add("Documenter")
```

Then, inside the ``./docsource`` folder, run in the terminal:

```bash
julia make.jl
```