"""
Função que recebe o conjunto de conteúdos terminais possíveis e faz a criação de um
nó terminal. Essa função, de uso interno, serve para criar um nó terminal com o
tratamento do ERC.

    _create_random_terminal(tSet::Vector{Union{Var, WeightedVar, Const, ERC}})::TerminalNode

A criação de um nó terminal envolve um passo de verificação adicional para
o caso de ERC, que deve substituir o nó por uma constante dentro do intervalo
especificado. 
"""
function _create_random_terminal(tSet::Vector{Union{Var, WeightedVar, Const, ERC}})::TerminalNode

    t = tSet[Random.rand(1:end)]
        
    if typeof(t) == ERC    
        # Sorteando um valor aleatório no intervalo do ERC e criando uma Const
        randVal = Random.rand()
        range = t.u_bound - t.l_bound
        
        return TerminalNode(Const( (randVal*range)+ t.l_bound ))
    else

        return TerminalNode(t) # Aqui é uma variável/variável com peso/constante
    end
end


"""
Função que cria uma árvore pelo método _grow_, inspirado no trabalho original de Koza.
Recebe um conjunto de funções  ```fSet::Vector{Func}``` que serão sorteadas para os
nós internos, um conjunto de funções ```tSet::Vector{Union{Var, WeightedVar, Const, ERC}}```
que serão utilizadas nos terminais, e uma profundidade máxima ```maxDepth::Int64``` permitida.
Retorna uma árvore qualquer com profundidade máxima ```maxDepth``` e utilizando os
conteúdos de funções e terminais passados.

    grow(fSet::Vector{Func}, tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, maxDepth::Int64)::AbstractNode

Repare que não há tamanho mínimo, significando que pode ser retornada uma árvore de um único nó.
A profundidade máxima considera variáveis com peso como um único nó.
"""
function grow(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    maxDepth::Int64)::AbstractNode

    if maxDepth <= 1 || Random.rand() < 1/maxDepth
        return _create_random_terminal(tSet)
    else
        idx = Random.rand(1:size(fSet, 1))
        
        return InternalNode(
            fSet[idx],
            AbstractNode[grow(fSet, tSet, maxDepth-1) for _ in 1:fSet[idx].arity]
        )
    end
end


"""
Função que cria uma árvore pelo método _full_, inspirado no trabalho original de Koza.
Recebe um conjunto de funções  ```fSet::Vector{Func}``` que serão sorteadas para os
nós internos, um conjunto de funções ```tSet::Vector{Union{Var, WeightedVar, Const, ERC}}```
que serão utilizadas nos  terminais, e uma profundidade máxima ```maxDepth::Int64``` permitida.
Retorna uma árvore qualquer com profundidade máxima ```maxDepth``` e utilizando os
conteúdos de funções e terminais passados.

    full(fSet::Vector{Func}, tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, maxDepth::Int64)::AbstractNode
"""
function full(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    maxDepth::Int64)::AbstractNode

    if maxDepth <= 1
        return _create_random_terminal(tSet)
    else
        idx = Random.rand(1:size(fSet, 1))
    
        return InternalNode(
            fSet[idx],
            AbstractNode[full(fSet, tSet, maxDepth-1) for _ in 1:fSet[idx].arity]
        )
    end    
end


"""
Criação de árvores com o método Probabilistic Tree Creator 2 (PTC2), descrito
em __Two Fast Tree-Creation Algorithms for Genetic Programming__, de Sean Luke.

Esse método se parece com o método _full_ de Koza, mas além de respeitar um limite de 
profundidade ```maxDepth```, respeita um limite de quantidade de nós ```expctdSize```.
O PTC2 garante que a profundidade não ultrapasse o máximo (no nosso caso, variáveis
com peso contam como profundidade 1), e garante que o número de
nós não ultrapasse o valor esperado somado da maior aridade entre as funções,
isso é, ``expctdSize + max(aridade(f)), f in fSet``.

    PTC2(
        fSet::Vector{Func}, 
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
        maxDepth::Int64,
        expctdSize::Int64)::AbstractNode

Aqui adotamos que a chance de selecionar um terminal ``t`` quando for necessário inserir
um terminal será uniforme para todos os terminais, e a chance de inserir uma função 
também seguirá a mesma lógica.

O algoritmo do PTC2 é descrito em C e faz o uso de pilhas e ponteiros. Em Julia, não
há todos esses recursos de forma simples, e uma adaptação dessas funções foi feita.
"""
function PTC2(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    maxDepth::Int64,
    expctdSize::Int64)::AbstractNode

    if expctdSize == 1 || maxDepth <= 1 # selecionar terminal aleatório e retorná-lo
        return _create_random_terminal(tSet)
    else
        f = fSet[Random.rand(1:end)] # Escolher um não terminal para ser a raíz

        # Criando com posições alocadas e vazias
        root = InternalNode(f, Array{AbstractNode}(undef, f.arity))

        currSize = 1 # Tamanho atual da árvore

        # Vamos utilizar um array simples para simular a fila aleatória. 
        # Guardamos tuplas com ("referência" para a posição do filho, profundidade do nó na árvore)
        randQueue = Tuple{Function, Int64}[] 

        for i in 1:root.func.arity # simulando ponteiros para atualizar os filhos
            push!(randQueue, (x -> root.children[i] = x, 1))
        end

        while size(randQueue)[1]+currSize < expctdSize && size(randQueue)[1] > 0
            
            # Pegando nó aleatório e tirando da fila 
            let randNode = Random.rand(1:size(randQueue)[1])
                nodeUpdater, nodeDepth = randQueue[randNode]
                deleteat!(randQueue, randNode)

                if nodeDepth >= maxDepth # Sortear terminal e colocar na profundidade máxima
                    terminal = _create_random_terminal(tSet)
                    nodeUpdater(terminal)
                    currSize = currSize + true_numberofnodes(terminal)
                else # Vamos colocar outro nó intermediário e enfileirar seus filhos

                    f = fSet[Random.rand(1:end)]
                    subtree = InternalNode(f, Array{AbstractNode}(undef, f.arity))
                    nodeUpdater(subtree)

                    for i in 1:subtree.func.arity 
                        push!(randQueue, (x -> subtree.children[i] = x, nodeDepth+1))
                    end

                    currSize = currSize + 1
                end
            end
        end

        # Preenchendo quem pode ter sobrado após atingir o limite máximo
        while size(randQueue)[1] > 0
            let randNode = Random.rand(1:size(randQueue)[1])
                nodeUpdater, nodeDepth = randQueue[randNode]
                deleteat!(randQueue, randNode)

                nodeUpdater(_create_random_terminal(tSet))
            end
        end
    end

    return root
end


"""
Função que inicializa uma população de tamanho ```popSize``` utilizando o método _grow_.

    init_pop_grow(
        fSet::Vector{Func}, 
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
        minDepth::Int64,
        maxDepth::Int64,
        expctdSize::Int64,
        popSize::Int64)::Vector{AbstractNode}

Todas as funções de inicialização recebem os mesmos parâmetros, mas nem todas fazem
uso de todos eles. Isso é apenas para unificar a chamada da criação de populações
"""
function init_pop_grow(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    minDepth::Int64,
    maxDepth::Int64,
    expctdSize::Int64,
    popSize::Int64)::Vector{AbstractNode}

    return AbstractNode[grow(fSet, tSet, maxDepth) for _ in 1:popSize]
end


"""
Função que inicializa uma população de tamanho ```popSize``` utilizando o método _full_.

    init_pop_full(
        fSet::Vector{Func}, 
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
        minDepth::Int64,
        maxDepth::Int64,
        expctdSize::Int64,
        popSize::Int64)::Vector{AbstractNode}

Todas as funções de inicialização recebem os mesmos parâmetros, mas nem todas fazem
uso de todos eles. Isso é apenas para unificar a chamada da criação de populações
"""
function init_pop_full(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    minDepth::Int64,
    maxDepth::Int64,
    expctdSize::Int64,
    popSize::Int64)::Vector{AbstractNode}

    return AbstractNode[full(fSet, tSet, maxDepth) for _ in 1:popSize]
end


"""
Função que inicializa uma população de tamanho ```popSize``` utilizando o método _ramped half-half_.

    init_pop_ramped(
        fSet::Vector{Func}, 
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
        minDepth::Int64,
        maxDepth::Int64,
        expctdSize::Int64,
        popSize::Int64)

Todas as funções de inicialização recebem os mesmos parâmetros, mas nem todas fazem
uso de todos eles. Isso é apenas para unificar a chamada da criação de populações
"""
function init_pop_ramped(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    minDepth::Int64,
    maxDepth::Int64,
    expctdSize::Int64,
    popSize::Int64)::Vector{AbstractNode}

    if popSize <= 0
        return AbstractNode[]
    end

    _range = maxDepth - minDepth + 1
    n      = popSize ÷ _range # divisão inteira
    q, r   = n÷2, n%2 

    treesFull = init_pop_full(fSet, tSet, 1, minDepth, expctdSize, q)
    treesGrow = init_pop_grow(fSet, tSet, 1, minDepth, expctdSize, q+r)
    trees     = init_pop_ramped(fSet, tSet, minDepth+1, maxDepth, expctdSize, popSize-n)

    return vcat(treesFull, treesGrow, trees)
end


"""
Função que inicializa uma população de tamanho ```popSize``` utilizando o método _PTC2_.

    init_pop_PTC2(
        fSet::Vector{Func}, 
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
        minDepth::Int64,
        maxDepth::Int64,
        expctdSize::Int64,
        popSize::Int64)::Vector{AbstractNode}

Todas as funções de inicialização recebem os mesmos parâmetros, mas nem todas fazem
uso de todos eles. Isso é apenas para unificar a chamada da criação de populações
"""
function init_pop_PTC2(
    fSet::Vector{Func}, 
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}}, 
    minDepth::Int64,
    maxDepth::Int64,
    expctdSize::Int64,
    popSize::Int64)::Vector{AbstractNode}
    
    return vcat([
        [PTC2(fSet, tSet, maxDepth, r) for _ in 1:(popSize ÷ expctdSize)]
        for r in 1:expctdSize
    ]...)
end