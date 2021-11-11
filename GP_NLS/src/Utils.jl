"""
Função que recebe um nó qualquer de uma árvore (```AbstractNode```) e recursivamente
constrói uma _string_ representando a árvore passada. Funções são denotadas sempre
na notação prefixada, com os argumentos entre parênteses.

    getstring(node::AbstractNode)::String

Implementa um despache múltiplo para cada subtipo de ```AbstractNode```.
"""
function getstring(node::TerminalNode)::String
        return node.terminal.str_rep
end

function getstring(node::InternalNode)::String
    child_str_rep = join([getstring(c) for c in node.children], ", ")

    return "$(node.func.str_rep)($(child_str_rep))"
end


"""
Função que recebe um nó qualquer de uma árvore (```AbstractNode```) e recursivamente
recria a estrutura, de forma que as referências não sejam compartilhadas entre a
árvore passada e a árvore retornada, evitando efeitos colaterais no manuseio.
Implementa despache múltiplo.

    copy_tree(node::AbstractNode)::TerminalNode
"""
function copy_tree(node::TerminalNode)::TerminalNode
    if typeof(node.terminal) == Var
        return TerminalNode(node.terminal)
    elseif typeof(node.terminal) == WeightedVar
        return TerminalNode(WeightedVar(node.terminal.var_name, node.terminal.var_idx, node.terminal.weight)) 
    else
        return TerminalNode(Const(node.terminal.value))
    end
end

function copy_tree(node::InternalNode)::InternalNode
    return InternalNode(node.func, [copy_tree(c) for c in node.children])
end


"""
Função que recebe um nó qualquer de uma árvore (```AbstractNode```) e recursivamente
encontra a profundidade da árvore como sendo o tamanho de seu maior galho.
Implementa múltiplo despache.

    depth(node::AbstractNode)::Int64

Essa profundidade corresponde ao número de nós existentes, sendo que os nós
de variáveis ponderadas (que são uma subárvore com profundidade 2) ainda são considerados
com profundidade 1.
"""
depth(node::TerminalNode)::Int64 = 1
depth(node::InternalNode)::Int64 = 1 + maximum([depth(c) for c in node.children])


"""
Função que recebe um nó qualquer de uma árvore (```AbstractNode```) e recursivamente
encontra a profundidade da árvore como sendo o tamanho de seu maior galho.
Implementa múltiplo despache.

    depth(node::AbstractNode)::Int64

Essa profundidade é real, e corresponde ao número de nós existentes, considerando a
profundidade da subárvore de variáveis com pesos. Essa função não é utilizada nas implementações,
e fica disponível para o usuário caso deseje obter a profundidade real considerando variáveis
ponderadas. 
"""
true_depth(node::TerminalNode)::Int64 = 1
true_depth(node::InternalNode)::Int64 = 1 + maximum([true_depth(c) for c in node.children])


"""
Função que recebe um nó qualquer de uma árvore (```AbstractNode```) e recursivamente
conta o total de nós que a árvore possui. Implementa múltiplo despache.

    numberofnodes(node::AbstractNode)::Int64

Essa função não considera variáveis ponderadas como um único nó.
"""
numberofnodes(node::TerminalNode)::Int64 = 1
numberofnodes(node::InternalNode)::Int64 = 1 + sum([numberofnodes(c) for c in node.children])


"""
Função que recebe um nó qualquer de uma árvore (```AbstractNode```) e recursivamente
conta o total de nós que a árvore possui. Implementa múltiplo despache.

true_numberofnodes(node::AbstractNode)::Int64

Essa função não considera variáveis ponderadas como três nós. Essa função só é utilizada
nas operações de mutação, crossover e inicialização para evitar árvores maiores que o 
permitido.
"""
true_numberofnodes(node::TerminalNode)::Int64 = typeof(node.terminal) == WeightedVar ? 3 : 1
true_numberofnodes(node::InternalNode)::Int64 = 1 + sum([true_numberofnodes(c) for c in node.children])


"""
Função que recebe o conjunto de filhos ```children::Vector{AbstractNode}``` e um
inteiro ```p``` (__que deve ser menor ou igual ao número de nós somados de todos 
os filhos passados__) e encontra o filho que contém o p-ésimo nó da árvore caso
fosse percorrida na ordem nó > filho 1 > filho 2 > .... ```p``` deve ser 
obtida pelo número de nós da árvore (não o número de nós real, considerando vários
nós em variáveis com peso).

    which_children(p::Int64, children::Vector{AbstractNode})::Tuple{Int64, AbstractNode}

Retorna uma tupla contendo o filho que contém o nó de índice desejado, e um inteiro
informando a posição do p-ésimo nó dentro da sub-árvore (filho) retornada.
"""
function which_children(p::Int64, children::Vector{AbstractNode})::Tuple{Int64, AbstractNode}
    if numberofnodes(children[1]) < p
        return which_children(p - numberofnodes(children[1]), children[2:end])
    else
        return (p, children[1])
    end
end


"""
Função que recebe um nó qualquer de uma árvore (```AbstractNode```) e um inteiro
```p``` (__que deve ser menor ou igual ao número de nós da árvore passada__) e
retorna o galho na posição ```p```.

    get_branch_at(p::Int64, node::AbstractNode)::AbstractNode
"""
function get_branch_at(p::Int64, node::AbstractNode)::AbstractNode
    if p <= 1
        return node
    else
        return get_branch_at(which_children(p-1, node.children)...)
    end
end


"""
Função que recebe um ponto ```p``` (__que deve ser menor ou igual ao número de
nós da árvore passada__), um galho do tipo ```AbstractNode``` e uma lista de filhos
```Vector{AbstractNode}``` e retorna uma modificação da lista de filhos, sendo que
o nó de posição ```p``` será substituído pelo galho passado. __Altera a lista de
filhos passada como argumento__.

    change_children!(p::Int64, branch::AbstractNode, children::Vector{AbstractNode})::Vector{AbstractNode}

Esse método é auxiliar de ```change_at!``` e de uso interno da biblioteca.
"""
function change_children!(p::Int64, branch::AbstractNode, children::Vector{AbstractNode})::Vector{AbstractNode}

    if size(children, 1) == 0 
        return Vector{AbstractNode}(undef, 0)
    end

    # Se o número de nós no primeiro filho for menor que p, sabemos que não é
    # esse filho que vai ser modificado, e vamos pro próximo
    if numberofnodes(children[1]) <= p
        return prepend!(
            change_children!(p-numberofnodes(children[1]), branch, children[2:end]),
            [children[1]]
        )
    else
        return prepend!(
            children[2:end],
            [change_at!(p, branch, children[1])]
        )
    end
end


"""
Recebe um ponto ```p``` do tipo inteiro (__que deve ser menor ou igual ao número de
nós da árvore passada__), um galho do tipo ```AbstractNode``` e um nó qualquer 
representando uma árvore```AbstractNode```, e insere o galho na árvore passada 
no nó de posição ```p```. __Altera a árvore passada como argumento__.

    change_at!(p::Int64, branch::AbstractNode, node::AbstractNode)::AbstractNode

Recebe um ponto, uma subárvore para inserir, e a árvore onde será inserida.
Esse método que realiza a modificação de uma árvore no _crossover_.
"""
function change_at!(p::Int64, branch::AbstractNode, node::AbstractNode)::AbstractNode

    # se não estamos no ponto de alterar, então será em algum filho desse ponto.
    # Vamos chamar altera_filhos na lista de filhos
    if p <= 1
        return branch
    else
        return InternalNode(node.func, change_children!(p-1, branch, node.children))
    end
end


"""
Recebe um ponto ```p``` do tipo inteiro (__que deve ser menor ou igual ao número de
nós da árvore passada__) e um nó qualquer representando uma árvore```AbstractNode```,
e encontra a profundidade da subárvore na posição ```p```.

    get_depth_at(p::Int64, node::AbstractNode)::Int64

É como o método de obter a profundidade, mas esse método calcula a profundidade
parcial de uma subárvore que está no ponto ```p```.
"""
function get_depth_at(p::Int64, node::AbstractNode)::Int64
    if p <= 1
        return 1
    else
        return 1 + get_depth_at(which_children(p-1, node.children)...)
    end
end


"""
Encontra todos os galhos de uma árvore qualquer ```node``` que tem uma quantidade
de nós menor ou igual que ```allowedSize``` __e__ uma profundidade menor ou igual
que ```allowedDepth``` . Retorna uma lista com a posição de todos os galhos encontrados.

    branches_in_limits(
        allowedSize::Int64, allowedDepth::Int64, node::AbstractNode, _point::Int64=1)::Vector{Int64}

O parâmetro ```_point``` é de uso interno, e serve para monitorar o ponto da árvore
onde foram encontrados os candidatos. Em chamadas recursivas ele faz sentido, mas fora 
da função ele não representa nenhuma informação útil.
"""
function branches_in_limits(
    allowedSize::Int64, allowedDepth::Int64, node::AbstractNode, _point::Int64=1)::Tuple{Vector{Int64}, Int64}
    
    found = Vector{Int64}(undef, 0)
    
    # Primeiro vamos ver se o nó em questão serve
    if true_numberofnodes(node) <= allowedSize && depth(node) <= allowedDepth
        push!(found, _point)
    end

    # Se tiver filhos, precisamos chamar recursivamente
    if typeof(node) == InternalNode

        # Temos que chamar os filhos passando o ponto que eles são na árvore
        for c in node.children
            child_found, _point = branches_in_limits(allowedSize, allowedDepth, c, _point+1)

            found = vcat(found, child_found)
        end
    end

    return found, _point
end