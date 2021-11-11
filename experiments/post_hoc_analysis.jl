### A Pluto.jl notebook ###
# v0.12.21

using Markdown
using InteractiveUtils

# ╔═╡ e406296e-8298-11eb-225e-855ff9b0d3f2
begin
    #Notebook para fazer a análise dos resultados
    
    using CSV
    using DataFrames
    using Statistics
    using Plots
    using StatPlots
    using HypothesisTests
end

# ╔═╡ 0fdc0b1e-8299-11eb-02bb-932d00e0ecf1
begin
    constResults  = CSV.File("../../results/ConstResults.csv")  |> DataFrame
    ERCResults    = CSV.File("../../results/ERCResults.csv")    |> DataFrame
	LsqOptResults = CSV.File("../../results/LsqOptResults.csv") |> DataFrame
end;

# ╔═╡ a5937568-829a-11eb-197e-e17fb978d33e
begin
    datasets = intersect(
		unique(constResults.Dataset),
		unique(ERCResults.Dataset),
		unique(LsqOptResults.Dataset)
	)
	
	to_plot = [ # Tuplas com título, labely e informação
		("Fitness no treino", "RMSE médio", "Fitness_treino", :topright, 0.3),
		("Fitness no teste",  "RMSE médio", "Fitness_teste",:topright, 0.3),
		("Número de nós", "Número de nós médio", "Numero_Nós_Real",:bottomright, 2),
		("Tempo de execução", "Tempo de execução (s) médio", "Tempo",:bottomright, 5),
	]
	
	for (title, ylabel, col_name, legend_pos, dspl) in to_plot
		displacement = dspl # distância entre anotações estatísticas e barra

		# --------------------------------------------------

		plot_data = hcat( # concatenando cada grupo que será plotado
			[constResults[constResults.Dataset .== d, col_name]   for d in datasets],
			[ERCResults[ERCResults.Dataset .== d, col_name]       for d in datasets],
			[LsqOptResults[LsqOptResults.Dataset .== d, col_name] for d in datasets]
		)

		final_plot = groupedbar(
			repeat(datasets, outer=3), # outer = n de grupos que temos
			mean.(plot_data),
			yerr=std.(plot_data),
			bar_position = :dodge, bar_width=0.7, xrotation = 30,
			group=repeat(
				["GP-Const", "GP-ERC", "GP-LsqOpt"], # Colocar aqui os grupos
				inner = size(datasets, 1)
			), 
			#xlabel = "Base de dados",
			ylabel = ylabel,
			#title = title,
			legend=legend_pos,
			fillrange=0,
			markerstrokecolor="black",
			markercolor="black",
			size = (1000, 500)
		)

		println(title)
		println(round.(mean.(plot_data), digits=2))
		println(round.(std.(plot_data),  digits=2))
		
		n_groups = size(plot_data, 2)

		# Calculando pvalores (3 grupos por dataset)
		stats_test = [ # lista de comparações para cada dataset
			# lista de tuplas com (p-valor, (tupla com indice grupos) )
			[( pvalue(SignedRankTest(plot_data[i, j], plot_data[i, k])), (j, k) )
				for j in 1:n_groups, k in [1, 3, 2] if k>j]
			for i in 1:size(datasets, 1)]

		# Ajustando alpha de forma simples
		alpha_bonferroni = 0.05/ size(stats_test, 1)*n_groups

		# Colocando anotações onde p_valor < alpha_bonferroni
		for (i, tests) in enumerate(stats_test)
			for (j, (test, pos)) in enumerate(tests)
				if test < alpha_bonferroni
					x_pos = i - 1 + 0.25*mean(pos)
					y_pos = maximum(
						mean.(plot_data[i, :]) + std.(plot_data[i, :])
					) + displacement*j*2
					annotate!(x_pos, y_pos + 1.25*displacement, "*")
					dist = (pos[2]-pos[1])/2
					plot!(
						[x_pos-0.25*dist,x_pos-0.25*dist,
							x_pos+0.25*dist, x_pos+0.25*dist],
						[y_pos+0.5*displacement, y_pos + displacement,
							y_pos + displacement, y_pos+0.5*displacement],
						label = false,
						linewidth=1.5,
						color="black"
					)
				end
			end
		end

		savefig(final_plot, "../../results/$(title).pdf")
		final_plot
	end
end

# ╔═╡ 57b163da-97b6-11eb-2683-31c5dcfb8057


# ╔═╡ Cell order:
# ╠═e406296e-8298-11eb-225e-855ff9b0d3f2
# ╠═0fdc0b1e-8299-11eb-02bb-932d00e0ecf1
# ╠═a5937568-829a-11eb-197e-e17fb978d33e
# ╠═57b163da-97b6-11eb-2683-31c5dcfb8057
