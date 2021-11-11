"""
Função que recebe um nó de uma árvore qualquer (```AbstractNode```) e percorre-a
recursivamente, procurando por todos os nós terminais que possuem como conteúdo
uma ```Const``` ou variável com peso ```WeightedVar```. Faz o uso interno de uma
lista ```Vector{AbstractNode}```, que é passada por referência para as chamadas
recursivas, que vão colocando uma referência para cada nó constante encontrado.

    find_const_nodes(node::AbstractNode, nodes=Vector{AbstractNode}())::Vector{TerminalNode}

Essa função é de uso interno do pacote, e é utilizado no método de otimização.
"""
function find_const_nodes(node::AbstractNode, nodes=Vector{AbstractNode}())::Vector{TerminalNode}
    
    if typeof(node) == TerminalNode
        if typeof(node.terminal) == Const || typeof(node.terminal) == WeightedVar
            push!(nodes, node)
        end
    else
        map(node.children) do child
            find_const_nodes(child, nodes)
        end
    end
    
    return nodes
end


"""
Função que recebe um nó de uma árvore qualquer (```AbstractNode```) e um vetor
do tipo ```theta::Vector{Float64}``` com o mesmo número de elementos que o número
de constantes da árvore passada, e recursivamente substitui as constantes da árvore
com os elementos de ```theta```. Não altera os argumentos passados, e retorna
uma nova árvore com as constantes substituídas ```theta``` deve ter o mesmo número
de ```Const``` e ```WeightedVar``` somados.

    replace_const_nodes(node::AbstractNode, theta::Vector{Float64}, _first_of_stack=true)::AbstractNode

o argumento ```_first_of_stack``` é de uso interno da função e serve para
criar uma cópia de ```theta``` que seja seguro remover elementos conforme vão
sendo utilizados.

Essa função é de uso interno do pacote, e é utilizado no método de otimização.
"""
function replace_const_nodes(node::AbstractNode, theta::Vector{Float64}, _first_of_stack=true)::AbstractNode

    if _first_of_stack
        theta = copy(theta)
    end
        
    if typeof(node) == TerminalNode
        if typeof(node.terminal) == Const
            
            new_value = theta[1]
            
            popfirst!(theta)
            
            return TerminalNode(Const(new_value))
        elseif typeof(node.terminal) == WeightedVar
            new_value = theta[1]
            
            popfirst!(theta)
            
            return TerminalNode(WeightedVar(node.terminal.var_name, node.terminal.var_idx, new_value))        
        else
            return TerminalNode(node.terminal)
        end
    else
        f = node.func
        
        children = AbstractNode[
            replace_const_nodes(c, theta, false) for c in node.children]
        
        return InternalNode(f, children)
    end
end


"""
Função que faz o evaluate simulando que ocorreu a substituição das constantes.
A ideia é simular que ouve a substitução sem a necessidade de reconstruir completamente
a árvore, buscando diminuir o custo computacional quando o método de otimização
realiza muitas iterações. Implementa múltiplo despache.

    evaluate_replacing_consts(
        node::Union{TerminalNode, InternalNode},
        X::Matrix{Float64},
        theta::Vector{Float64},
        c_idx::Int64=0)::Tuple{Vector{Float64}, Int64}

Essa função é de uso interno do pacote, e é utilizado no método de otimização.

A variável ```c_idx``` é utilizada internamente para ter controle dos índices
de ```theta``` que já foram utilizados ou não, para que a simulação da substituição
seja feita corretamente.
"""
function evaluate_replacing_consts(
    node::TerminalNode, X::Matrix{Float64}, theta::Vector{Float64}, c_idx::Int64=0)::Tuple{Vector{Float64}, Int64}

    if typeof(node.terminal) == Var
        return X[:, node.terminal.var_idx], c_idx
    elseif typeof(node.terminal) == WeightedVar
        c_idx += 1
        return X[:, node.terminal.var_idx].*theta[c_idx], c_idx
    else
        c_idx += 1
        return ones(size(X,1)) * theta[c_idx], c_idx
    end
end

function evaluate_replacing_consts(
    node::InternalNode, X::Matrix{Float64}, theta::Vector{Float64}, c_idx::Int64=0)::Tuple{Vector{Float64}, Int64}
    
    args = map(node.children[1:node.func.arity]) do child
        evaluated, c_idx = evaluate_replacing_consts(child, X, theta, c_idx)
        evaluated
    end

    return node.func.func(args...), c_idx
end


# Vamos criar funções constantes que sabemos que são necessárias para a adaptação
# utilizada no processo de otimização
const adapt_sum  = Func(+, 2)
const adapt_prod = Func(myprod, 2)


"""
Função que recebe uma árvore e faz as adaptações necessárias para poder aplicar
a otimização com o método de mínimos quadrados não linear. Não modifica os argumentos.
Retorna uma função que recebe ```X``` e ```theta``` para realizar a avaliação da árvore
(e não só ```X```), o vetor ```theta``` inicial, que corresponde aos coeficientes
iniciais da árvore antes do processo de otimização, e uma árvore adaptada.

    adaptate_tree(node::AbstractNode)::Tuple{Function, Vector{Float64}, AbstractNode}

A adaptação requerida é feita colocando 4 novos nós na árvore, que servem para
que ela tenha um intercepto e um coeficiente angular. Essa função faz a adaptação,
e retorna também um vetor com os valores das constantes originais, junto de uma
função que depende de ```X::Matrix{Float64}``` e ```theta::Vector{Float64}``` para
realizar a avaliação (```evaluate```). A função ```H``` retornada é internamente
utilizada em um algoritmo de autodiff para obter a Jacobiana no método de otimização.

Essa função é de uso interno do pacote, e é utilizado no método de otimização.
"""
function adaptate_tree(node::AbstractNode)::Tuple{Function, Vector{Float64}, AbstractNode}
    
    # Placeholder do intercepto e coeficiente angular será 1.0. Vamos adicionar os nós:
    with_scaling = InternalNode(adapt_prod, [node, TerminalNode(Const(1.0))])
    with_offset  = InternalNode(adapt_sum, [with_scaling, TerminalNode(Const(1.0))])
    
    # Encontrar as constantes e formar o vetor theta inicial
    const_nodes = find_const_nodes(with_offset)

    # Construindo o vetor de coeficientes originais
    p0 = [typeof(c.terminal) == Const ? c.terminal.value : c.terminal.weight for c in const_nodes]
    
    # Gerando a função que usa a árvore ajustada e depende de X e theta para predizer
    return (
        (X, theta) -> evaluate_replacing_consts(with_offset, X, theta)[1],
        p0,
        with_offset
    )
end


"""
Função que recebe um nó de uma árvore qualquer (```AbstractNode```), uma matriz com 
os atributos ```X::Matrix{Float64}```, e um vetor com valores esperados
```y::Vector{Float64}```, e aplica um processo de otimização baseado no método
dos mínimos quadrados não linear, fazendo uma adaptação na árvore. Retorna uma árvore adaptada.

    apply_local_opt(node::AbstractNode, X::Matrix{Float64}, y::Vector{Float64}, keep_linear_transf_box=false)::AbstractNode

Podemos escolher retornar a expressão utilizando os nós de escala linear ou não.
No caso de ser retornado, vale notar que o código não irá aplicar mutação ou 
crossover nos nós do bloco.

Essa função é de uso interno do pacote, e é utilizado no método de otimização.
"""
function apply_local_opt(node::AbstractNode, X::Matrix{Float64}, y::Vector{Float64}, keep_linear_transf_box=false)
    node_H, node_p0, node_adapted = adaptate_tree(node)
    
    # Utilizar vários 1's como ponto inicial da otimização
    #node_p0 = ones(size(node_p0, 1))

    try
        fit = curve_fit(
            node_H,
            X,
            y,
            node_p0,
            maxIter=7,
            autodiff=:forward #["forwarddiff", "finiteforward", <default é _finite differences_>]
        )
        
        theta = fit.param
        
        node_optimized = replace_const_nodes(node_adapted, theta)

        # Precisamos remover os nós de offset e slope, eles são para que a otimização
        # se preocupe em corrigir a árvore sem pensar no offset. No artigo, eles também
        # utilizam o R2 como fitness. Sabemos onde foram adicionados os nós novos,
        # vamos pegar o filho na posição da árvore correspondente
        if keep_linear_transf_box
            return node_optimized
        else
            return node_optimized.children[1].children[1]
        end
    catch err
        # podemos ter erros na diferenciação automática se for gerada uma árvore
        # onde as derivadas não são contínuas dentro do intervalo dos dados.
        # Vamos retornar a função sem ajustar os coeficientes então. É esperado que ---
        # caso a otimização seja bem sucedida em algumas expressões e gere melhoria no
        # fitness --- que elas passem a ocorrer mais na população e eventualmente tenhamos uma
        # população que falhe pouco na diferenciação.

        #print(err)
        if keep_linear_transf_box
            return node_adapted
        else
            return node_adapted.children[1].children[1]
        end
    end
end