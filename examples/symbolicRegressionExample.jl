### A Pluto.jl notebook ###
# v0.14.7

using Markdown
using InteractiveUtils

# ╔═╡ 30fd5cce-4613-11ec-14f1-29644d72169d
begin
	using CSV
	using DataFrames	
	using Random
	using MLDataUtils
	using BenchmarkTools
	
	using GP_NLS
	using PlutoUI
end

# ╔═╡ 54a4efd4-4613-11ec-1f42-f354d36aeb30
begin
	df_data = CSV.File("../datasets/airfoil.csv") |> DataFrame
	
	df_data = df_data[Random.shuffle(1:end), :]
		
	train, test = splitobs(df_data, at = 0.7)
	
	train_X = convert(Matrix{Float64}, train[:, 1:end-1])
	train_y = convert(Vector{Float64}, train[:, end])
	
	test_X  = convert(Matrix{Float64}, test[:, 1:end-1])
	test_y  = convert(Vector{Float64}, test[:, end])
	
	describe(df_data, :mean, :min, :median, :max)
end

# ╔═╡ 4a19fda2-4613-11ec-3a2e-f94259597559
begin
	
	# Creating the variable nodes for the data set
	varSet = Union{Var, WeightedVar}[
		WeightedVar(var_name, i)
		for (i, var_name) in enumerate(names(df_data)[1:end-1])]
	    
	# Creating ERC nodes
	ERCSet = ERC[
	    ERC(-100.0, 100.0),
	]
	
	# Creating const nodes
	ConstSet = Const[
	    Const(1.5707),
		Const(3.1415),

		Const(-1.5707),
		Const(-3.1415),
	]
	
	# Terminals will be picked from the union
	terminalSet = Array{Union{Const, Var, WeightedVar, ERC}}(
		vcat(ERCSet, varSet, ConstSet))
	
	# Using default functions set
	functionSet = defaultFunctionSet 
end;

# ╔═╡ bf864a27-7ab2-43d4-a6d1-03212776c5c1
with_terminal() do
	println("Terminal nodes:")
	for t in terminalSet
		println(" - $(t)")
	end
end

# ╔═╡ f75c4b8b-5b24-4361-adca-2cb88fac5ceb
with_terminal() do
	println("Function nodes:")
	for f in functionSet
		println(" - $(f)")
	end
end

# ╔═╡ bdf61864-4613-11ec-012e-a385b0572482
with_terminal() do
	exec_time = @elapsed(bestsol = GP(

		# Mandatory arguments
		train_X,     # Train independent variables matrix
		train_y,     # Train dependent variable vector
		functionSet, # Function set
		terminalSet, # Terminal set

		# From this point every argument should be named and are optional
		minDepth               = 1,                 
		maxDepth               = 5 - 2 - 1,        
		maxSize                = 25 - 4,             
		popSize                = 100,                
		gens                   = 100,                   
		mutationRate           = 0.05,          
		elitism                = true,               
		verbose                = false,              
		init_method            = "PTC2",        
		lm_optimization        = true,      
		keep_linear_transf_box = true
	))
	
	results = Dict(
		"Execution time"              => exec_time,
		"Train RMSE"                  => fitness(bestsol, train_X, train_y),
		"Test RMSE"                   => fitness(bestsol, test_X, test_y),
		"Number of nodes"             => true_numberofnodes(bestsol),
		"Depth"                       => depth(bestsol),
		"String infix representation" => getstring(bestsol),
	)
	
	for (k, v) in results
		println("$(k) => $(v)")
	end
end

# ╔═╡ Cell order:
# ╠═30fd5cce-4613-11ec-14f1-29644d72169d
# ╠═54a4efd4-4613-11ec-1f42-f354d36aeb30
# ╠═4a19fda2-4613-11ec-3a2e-f94259597559
# ╠═bf864a27-7ab2-43d4-a6d1-03212776c5c1
# ╠═f75c4b8b-5b24-4361-adca-2cb88fac5ceb
# ╠═bdf61864-4613-11ec-012e-a385b0572482
