"""
Função que recebe um nó qualquer de uma árvore (```AbstractNode```), e implementa
um despache múltiplo para o caso de ```TerminalNode``` e ```InternalNode```, e 
uma matriz de dados ```X```. Função para avaliar uma base de dados utilizando a árvore
passada.

    evaluate(node::Union{TerminalNode, InternalNode}, X::Matrix{Float64})::Vector{Float64}

A função faz uma chamada recursiva ao longo do nó passado e avalia a expressão
utilizando as colunas de variáveis da matriz que existem na árvore.

Caso o nó seja uma função, a chamada recursiva é feita com seus filhos e o resultado
é utilizado como argumentos na função. Caso seja uma constante, um vetor com 
```size(X, 1)``` contendo repetidas vezes a constante é retornado. Caso seja uma
variável, a coluna de ```X``` de mesmo índice ```Var.var_idx``` será utilizado
para extrair um vetor da matriz.
"""
function evaluate(node::TerminalNode, X::Matrix{Float64})::Vector{Float64}
    if typeof(node.terminal) == Var

        return X[:, node.terminal.var_idx]
    elseif typeof(node.terminal) == WeightedVar

        return X[:, node.terminal.var_idx].*node.terminal.weight
    else

        return ones(size(X,1)) * node.terminal.value
    end
end

function evaluate(node::InternalNode, X::Matrix{Float64})::Vector{Float64}
    args = map(node.children[1:node.func.arity]) do child
        evaluate(child, X)
    end

    return node.func.func(args...)
end


"""
Função que mede o fitness de uma árvore qualquer, em relação a uma matriz de observações
```X::Matrix{Float64}``` e um vetor de resultados esperados ```y::Vector{Float64}```.

    fitness(tree::AbstractNode, X::Matrix{Float64}, y::Vector{Float64})::Float64

O fitness é calculado utilizando o RMSE, e esse método retorna um fitness
infinito caso a árvore falhe em avaliar --- fazendo com que a pressão seletiva
seja forte e provavelmente elimine o indivíduo da população sem ter que pensar em
operações protegidas, o que é particularmente interessante por não aumentar a
complexidade das funções dos nós, já que é feito o uso de um autodiff para diferenciar
a árvore, e pode ser problemático diferenciar funções com IFS ou cálculos mais elaborados.
"""
function fitness(tree::AbstractNode, X::Matrix{Float64}, y::Vector{Float64})::Float64

    # Vamos fazer um bloco para cuidar de erros aqui -> atribuir fitness alto
    try
        RMSE = sqrt( mean( (evaluate(tree, X) .- y).^2 ) )
        
        isfinite(RMSE) ? RMSE : Inf
    catch err
        return Inf
    end
end