"""
Tipo abstrato de nó de árvore. A ideia é fazer esse tipo para deixar claro que
```InternalNode``` e ```TerminalNode``` são uma derivação desse tipo, e possibilitar
assinaturas de funções que independem do tipo específico de nó, mas ainda possibilitar 
diferenciar a assinatura quando eles dependem ou tem comportamentos diferentes para cada caso
(fazendo uso de despache múltiplo).

As árvores de expressão não devem ser construídas com ```Var, WeightedVar, Const, Func, ERC```,
e sim com esses nós, que são então o esqueleto da árvore, enquanto os anteriores
são seus conteúdos. Um nó terminal só pode ter conteúdo ```Const, Var, WeightedVar```,
e um nó intermediário só pode ter conteúdo do tipo ```Func```.

(Note que o ERC, ao ser sorteado para ser um terminal, é substituído por uma Const
aleatória e então inserido no terminal)
"""
abstract type AbstractNode end


"""
_Struct_ que forma o esqueleto da árvore, utilizado apenas em nós terminais. É o
encapsulamento apenas de ```Union{Const, Var, WeightedVar}```. 

    TerminalNode(terminal::Union{Const, Var, WeightedVar}) <: AbstractNode
"""
struct TerminalNode <: AbstractNode
    terminal :: Union{Const, Var, WeightedVar}
end


"""
_Struct_ que forma o esqueleto da árvore, utilizado apenas nos nós internos, para
encapsular uma função ```f :: Func``` que terá, obrigatóriamente ```f.arity``` filhos.

    InternalNode(f::Func, children::Vector{AbstractNode}) <: AbstractNode
"""
struct InternalNode <: AbstractNode
    func     :: Func
    children :: Vector{AbstractNode}
end