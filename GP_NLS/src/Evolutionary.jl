"""
Função que recebe dois indivíduos e faz uma seleção por torneio simples.
Um indivíduo é uma tupla ```(fitness::Float64, node::AbstractNode)``` com a árvore
e seu fitness, para evitar que seja recalculado a todo instante.

    tourn_selection(ind1::Tuple{Float64, AbstractNode}, ind2::Tuple{Float64, AbstractNode})::Tuple{AbstractNode, Float64}

O retorno é uma tupla com o indivíduo vencedor (ou seja, é retornada uma tupla).
"""
function tourn_selection(ind1::Tuple{AbstractNode, Float64}, ind2::Tuple{AbstractNode, Float64})

    _, fitness1 = ind1
    _, fitness2 = ind2
    
    return fitness1 < fitness2 ? ind1 : ind2
end


"""
Função de crossover que faz uma recombinação dos dois pais passados como argumento,
encontrando um ponto de quebra em cada uma das árvores pais e trocando a subárvore entre esses
pontos. Não modifica os pais. Esse crossover controla o número de nós (e não a profundidade).

    crossover(
        fst_parent::AbstractNode,
        snd_parent::AbstractNode,
        maxDepth::Int64,
        maxSize::Int64)::AbstractNode

Queremos que o crossover ocorra em um ponto de corte que não causa o aumento da
árvore filha para algo maior que o limite.
"""
function crossover(
    fst_parent::AbstractNode, snd_parent::AbstractNode, maxDepth::Int64, maxSize::Int64)::AbstractNode

    # primeiro pegamos um ponto de corte qualquer na primeira árvore
    child = copy_tree(fst_parent)
    child_point = Random.rand(1:numberofnodes(child))

    # Definimos o tamanho máximo permitido como (tamanho máximo - tamanho da árvore parcial)
    # (tamanho da arvore parcial seria o tamanho da árvore - tamanho do galho que
    # será removido no crossover). Vamos utilizar o número real de nós.
    partialSize = true_numberofnodes(fst_parent) - true_numberofnodes(get_branch_at(child_point, fst_parent))
    
    # usar esse max pois pode ser que as árvores ultrapassem o tamanho por poucas unidades por conta do PTC2
    allowedSize = max(maxSize - partialSize, 1)

    # O mesmo do tamanho também vale para a profundidade
    allowedDepth = max(maxDepth - get_depth_at(child_point, fst_parent), 1)

    # Encontramos todas as subárvores no segundo pai que não tem tamanho maior que o permitido
    candidates, _ = branches_in_limits(allowedSize, allowedDepth, snd_parent)
    
    if length(candidates) == 0
        return child
    end

    # Selecionamos uma aleatoriamente e trocamos, criando um novo filho
    branch_point = candidates[Random.rand(1:end)]
    branch = copy_tree(get_branch_at(branch_point, snd_parent))

    return change_at!(child_point, branch, child)
end


"""
Função que implementa uma mutação tradicional de substituição em uma árvore,
respeitando a  profundidade máxima passada. __Modifica a árvore passada__.

    mutation!(
        node::AbstractNode,
        maxDepth::Int64,
        maxSize::Int64,
        fSet::Vector{Func},
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}},
        mutationRate::Float64
    )::AbstractNode

A taxa de mutação ```mutationRate``` deve variar em ``[0, 1]`` e determina a chance
de ocorrer uma mutação (substituindo um ponto aleatório por uma nova sub-árvore) ou
o próprio nó passado ser retornado.
"""
function mutation!(
    node::AbstractNode,
    maxDepth::Int64,
    maxSize::Int64,
    fSet::Vector{Func},
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}},
    mutationRate::Float64)::AbstractNode
    
    if Random.rand() >= mutationRate
        return node
    end

    point = Random.rand(1:numberofnodes(node))
    
    # tamanho esperado é algo entre o permitido e o máximo, sorteado aleatoriamente
    randVal    = Random.rand()
    range      = maxSize - true_numberofnodes(get_branch_at(point, node))
    expctdSize = floor(Int64, randVal*range) + true_numberofnodes(get_branch_at(point, node))

    # Tamanho esperado é o mesmo tamanho do galho que foi mutacionado
    #expctdSize = numberofnodes(get_branch_at(point, node))

    allowedDepth = maxDepth - (get_depth_at(point, node))

    random_branch = PTC2(fSet, tSet, allowedDepth, expctdSize)
    
    return change_at!(point, random_branch, node)
end


"""
GP Com controle de profundidade e número de nós. A inicialização recomendada é
a PTC2, mas temos as outras também (entretanto, os outros métodos são baseados
no GP do koza e não seguem restrição de número máximo de nós).

    GP(
        X::Matrix{Float64}, 
        y::Vector{Float64},
        fSet::Vector{Func},
        tSet::Vector{Union{Var, WeightedVar, Const, ERC}},
        minDepth::Int64        = 1,
        maxDepth::Int64        = 5,
        maxSize::Int64         = 25,
        popSize::Int64         = 50,
        gens::Int64            = 50,
        mutationRate::Float64  = 0.25,
        elitism::Bool          = false,
        verbose::Bool          = false,
        init_method::String    = "PTC2", #["ramped", "grow", "full", "PTC2"]
        lm_optimization        = false, 
        keep_linear_transf_box = false
    )::AbstractNode

"""
function GP(
    X::Matrix{Float64}, 
    y::Vector{Float64},
    fSet::Vector{Func},
    tSet::Vector{Union{Var, WeightedVar, Const, ERC}},
    minDepth::Int64        = 1,
    maxDepth::Int64        = 5,
    maxSize::Int64         = 25,
    popSize::Int64         = 50,
    gens::Int64            = 50,
    mutationRate::Float64  = 0.25,
    elitism::Bool          = false,
    verbose::Bool          = false,
    init_method::String    = "PTC2", #["ramped", "grow", "full", "PTC2"]
    lm_optimization        = false, 
    keep_linear_transf_box = false
)::AbstractNode
    # Função para reverter o zip, será util com o tournament
    unzip(a) = map(x->getfield.(a, x), fieldnames(eltype(a)))

    # Primeiro vamos inicializar a população e fazer o primeiro fit
    population = eval(Symbol("init_pop_$(init_method)"))(
        fSet, tSet, minDepth, maxDepth, maxSize, popSize)

    # O passo de otimização vem antes de calcular o fitness
    if lm_optimization
        population = AbstractNode[
            apply_local_opt(p, X, y, keep_linear_transf_box) for p in population]
    end

    # Antes de mais nada, vamos pegar o fitness da população toda
    fitnesses = [fitness(p, X, y) for p in population]

    if verbose
        println("\nGer,\t smlstFit,\t LargestNofNodes,\t LargestDepth")
    end

    bestSoFar, bestFitness = nothing, nothing
    for g in 1:gens
        
        # No começo da geração temos a população e os fitnesses, vamos montar os indivíduos
        finites     = isfinite.(fitnesses) # máscara com apenas fitness finitos
        individuals = collect(zip(population[finites], fitnesses[finites]))
        
        # Pegando o melhor da população antes das operações genéticas
        if elitism
            bestSoFar, bestFitness = individuals[argmin(fitnesses[finites])]
            bestSoFar = copy_tree(bestSoFar)
        end

        if verbose
            # Pegando informações para printar
            i1 = minimum(filter(isfinite, fitnesses))
            i2 = maximum([true_numberofnodes(p) for p in population[finites]])
            i3 = maximum([true_depth(p) for p in population[finites]])
            
            println("$g,\t $(i1),\t $(i2),\t $(i3)")
        end

        parents, fitnesses = unzip(Tuple{AbstractNode, Float64}[ # Selecionando pais para crossover
            tourn_selection(
                individuals[Random.rand(1:end)], 
                individuals[Random.rand(1:end)]
            ) for _ in 1:popSize])       
        
        # na hora de crossover e mutação, queremos tirar os nós da transformação linear.
        # Vamos tirar aqui antes de fazer essas operações, pois no final da geração
        # eles serão adicionados e otimizados novamente, e o fitness é atualizado.
        
        # Aplicando crossover. (crossover retorna cópia, mutação modifica referência)
        children = if lm_optimization && keep_linear_transf_box
            # Sabemos o nó onde fica a árvore original. Vamos criar uma cópia para não
            # alterar a subárvore dos originais (mas manteremos referência aos originais para seleção)
            AbstractNode[
                crossover(
                    parents[Random.rand(1:end)].children[1].children[1],
                    parents[Random.rand(1:end)].children[1].children[1],
                    maxDepth,
                    maxSize
                ) for _ in 1:popSize]
        else
            AbstractNode[
                crossover(
                    parents[Random.rand(1:end)],
                    parents[Random.rand(1:end)],
                    maxDepth,
                    maxSize
                ) for _ in 1:popSize]
        end

        # Crossover gera cópias, podemos modificar com a mutação aqui
        children = AbstractNode[
            mutation!(c, maxDepth, maxSize, fSet, tSet, mutationRate) for c in children]
        
        # O passo de otimização vem antes de calcular o fitness, só nos filhos
        if lm_optimization
            children = AbstractNode[
                apply_local_opt(c, X, y, keep_linear_transf_box) for c in children]
        end

        # Torneio para a próxima geração. Já temos o fitness dos pais calculados, só
        # precisamos calcular metade 
        fitnesses   = vcat(fitnesses, [fitness(c, X, y) for c in children])
        
        finites     = isfinite.(fitnesses) 
        individuals = collect(zip( vcat(parents, children)[finites], fitnesses[finites] ))
        
        population, fitnesses = unzip(Tuple{AbstractNode, Float64}[
            tourn_selection(
                individuals[Random.rand(1:end)], individuals[Random.rand(1:end)]
            ) for _ in 1:popSize])

        if elitism # Vamos operar com um a mais.
            push!(population, bestSoFar)
            push!(fitnesses, bestFitness)
        end
    end
    
    return population[argmin([fitness(p, X, y) for p in population])]
end