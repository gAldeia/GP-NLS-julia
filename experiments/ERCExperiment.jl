using CSV
using DataFrames	
using Random
using MLDataUtils
using BenchmarkTools

using GP_NLS # Essa biblioteca está no path do julia, mas é minha!

df_names = ["airfoil", "cars", "concrete", "energyCooling", "energyHeating", "grossOutput",
     "qsarAquaticToxicity", "wineRed", "wineWhite", "yachtHydrodynamics"]

# Podemos passar o nome dos datasets que o processo deve executar, ou ele executa todos sequencialmente
if size(ARGS, 1) > 0
    df_names = intersect(Set(df_names), Set(ARGS))
    if length(df_names) == 0
        println("Nenhum dos nomes de datasets passados existem")
        exit()
    else
        println("Executando agora para os datasets $(df_names)")
    end
else
    println("Executando todos os datasets sequencialmente ($(df_names))")
end

functionSet = defaultFunctionSet # Vamos utilizar o padrão fornecido

ERCSet = ERC[
    ERC(-1.0, 1.0),
    ERC(-10.0, 10.0),
    ERC(-100.0, 100.0),
]

# Recuperando resultados anteriores ou preparando um DataFrame para salvar os novos
df_results = try
    CSV.File("./results/ERCResults.csv") |> DataFrame
catch err
    DataFrame(Dataset=[], Execução=[], Tempo=[], Fitness_treino=[],
        Fitness_teste=[], Numero_Nós=[], Numero_Nós_Real=[], Profundidade=[], Expressão=[])
end

for df_name in df_names
    print("Testes para a base $df_name: ")

    df_data = CSV.File("../datasets/$(df_name).csv") |> DataFrame

    # Embaralhar os dados, pois algumas bases costumam
    df_data = df_data[Random.shuffle(1:end), :]

    # Vamos criar o conjunto de terminais. Será a combinação de variáveis e constantes apenas
    varSet = Union{Var, WeightedVar}[
        Var(var_name, i) for (i, var_name) in enumerate(names(df_data)[1:end-1])
    ]
    
    # Finalmente, os terminais serão a junção de constantes, erc e variáveis
    terminalSet = Array{Union{Const, Var, WeightedVar, ERC}}(vcat(ERCSet, varSet))

    # Filtrando arquivo de resultados para ver quantas execuções temos
    df_filtro = df_results[df_results.Dataset .== df_name, :]

    for i in 1:30
        # Vamos ver se tem ou não esses dados de execução
        if size(df_filtro[df_filtro.Execução .== i, :], 1) == 0
            print("$i ")

            # Separando tudo em treino e teste
            train, test = splitobs(df_data, at = 0.7)
    
            # Separando treino e teste em X e y
            train_X, train_y = train[:, 1:end-1], train[:, end]
            test_X,  test_y  = test[:, 1:end-1],  test[:, end]

            # Salvando o tempo de execução da macro @elapsed e a melhor solução
            exec_time = @elapsed (bestsol = GP(
                convert(Matrix{Float64}, train_X), # Matriz observações X atributos
                convert(Vector{Float64}, train_y), # Vetor de valores esperados
                functionSet,                       # Conjunto de funções para nós internos
                terminalSet,                       # Conjunto de terminais para folhas
                1,                                 # Profundidade mínima da árvore
                10,                                # Profundidade máxima da árvore
                75,                                # Número máximo de nós
                250,                               # Tamanho da população
                400,                               # Número de gerações
                0.25,                              # Chance de ocorrer uma mutação
                true,                              # Uso de elitismo (true, false)
                true,                              # Verbose (pode impactar performance)
                "PTC2",                            # Modo de inicialização (half-half, full, grow)
                false,                             # Fazer o uso do passo de otimização não linear
                false                              # manter os nós de transformação linear na otimização
            ))

            # Salvando os resultados da execução
            push!(df_results, (
                df_name,
                i,
                exec_time,
                fitness(bestsol, convert(Matrix, train_X), convert(Vector{Float64}, train_y)),
                fitness(bestsol, convert(Matrix, test_X), convert(Vector{Float64}, test_y)),
                numberofnodes(bestsol),
                true_numberofnodes(bestsol),
                depth(bestsol),
                getstring(bestsol),
            ))
            
            # Escrevendo após cada repetição
            CSV.write("./results/ERCResults.csv", df_results)

            # Vamos forçar o coletor de lixo por garantias
            GC.gc()
        end
    end

    # Fim para o dataset, vamos para o próximo
    println("finalizado.")
end