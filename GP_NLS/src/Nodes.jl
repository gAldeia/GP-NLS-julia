"""
_Struct_ para representar uma função de um nó interno de uma árvore de expressão.

    Func(f::Function, a::Int64)

Recebe uma função ```f``` e a aridade da função ```a```. A função deve sempre funcionar
na forma vetorizada (receberá sempre ``a`` arrays (com ``n`` valores, onde cada um
é uma observação, sendo cada array um argumento da função) e é aplicada sobre os arrays. 
Então a entrada da função terá ```a``` linhas e ```n``` colunas.

A representação da função em _string_ é inferida do nome da função passada, e quando
essa função for utilizada para criar um nó de uma árvore, ela terá ``a`` filhos.

Na implementação dessa biblioteca, não devem ser utilizados operadores protegidos,
já que é feito o uso de um autodiff para diferenciar a árvore, e pode ser problemático
diferenciar funções com IFs ou cálculos mais elaborados para proteger a função.
"""
struct Func
    func    :: Function
    arity   :: Int64
    str_rep :: String

    Func(f::Function, a::Int64) = new(f, a, string(f))
end


"""
_Struct_ para representar um valor Float64 constante nos terminais das árvores. 

    Const(v::Float64)

Recebe um valor Float64 ```v``` que será utilizado como constante.

A representação da constante como _string_ é obtida arredondando o valor 
para 3 casas decimais, e é obtida automaticamente

O método de otimização com mínimos quadrados não linear busca por essa _struct_
especificamente para fazer a otimização dos seus valores.
"""
struct Const
    value   :: Float64
    str_rep :: String

    Const(v:: Float64) = new(v, string(round(v, digits=3)))
end


"""
_Struct_ que guarda os limites do intervalo de criação de uma constante aleatória.

    ERC(lb::Float64, ub::Float64)

Essa _struct_ é utilizada para criação de constantes nos terminais quando é selecionada,
sendo que será criado um terminal com a _struct_ ```Const``` com um valor aleatório
sorteado entre ```[lb, ub)``` para ocupar o lugar do ERC (_Ephemeral Random Constant_)
no terminal. A representação em _string_ da constante criada é como descrito na
documentação de ```Const```.
"""
struct ERC
    l_bound :: Float64
    u_bound :: Float64
    
    ERC(lb::Float64, ub::Float64) = new(lb, ub)
end


"""
_Struct_ que representa uma variável do problema, e é utilizada nos terminais das árvores.

    Var(v::String, i::Int64)

Recebe uma _string_ ```v``` que será utilizada como representação da variável na
hora de imprimir os dados (pode-se utilizar um _placeholder_ caso a base de dados
não tenha nome nas colunas) e um índice ```ì``` que corresponde ao índice da coluna
da variável correspondente na matriz da base de dados.
"""
struct Var
    var_name :: String
    var_idx  :: Int64
    str_rep  :: String

    Var(v::String, i::Int64) = new(v, i, v)
end


"""
_Struct_ de uma variável com coeficiente. Utilizar quando quisermos que as variáveis
criadas tenham sempre um coeficiente associado à elas no momento de criação.

    WeightedVar(v::String, i::Int64) = new(v, i, v)

Essa struct representa uma variável com peso que pode ser ajustado pelo método
de otimização (ou definido antes da execução pelo utilizador, por meio do 
múltiplo despache do construtor da struct).

A representação em _String_ é inferida da forma que uma ``Var`` em relação ao nome
da variável, e o coeficiente é inferido da mesma forma que uma ``Const``.

Essa variável ponderada é, na teoria, uma sub-árvore com 3 nós e profundidade 2,
mas na prática é tratada como um único nó pois não é de interesse fazer uma
dissociação entre o peso e a variável durante o processo evolutido.
Ao tratar a variável com peso como um único nó, não é necessario modificar
nenhuma implementação de crossover ou mutação para que não seja destruída essa
subárvore.
"""
struct WeightedVar
    var_name :: String
    var_idx  :: Int64
    str_rep  :: String
    weight   :: Float64

    WeightedVar(v::String, i::Int64)             = new(v, i, "1.0*$(v)", 1.0)
    WeightedVar(v::String, i::Int64, w::Float64) = new(v, i, "$(round(w, digits=3))*$(v)", w)
end

    
# Para facilitar o uso e servir como exemplo, alguns conjuntos padrões serão fornecidos.
# Declaramos como const para evitar que mudem o valor, e deixar explícito que não deveriam.
const myprod(args...)    = args[1] .* args[2]
const mydiv(args...)     = args[1] ./ args[2] # Note que não é divisão protegida!
const mysin(args...)     = sin.(args[1])
const mycos(args...)     = cos.(args[1])
const mysqrtabs(args...) = sqrt.(abs.(args[1]))
const mysqrt(args...)    = sqrt.(args[1])
const mysquare(args...)  = args[1].^2
const myexp(args...)     = exp.(args[1])
const mylog(args...)     = log.(args[1])

#mysin(args) = sin.(args) # Seria possível receber só um argumento se for unária, mas é melhor manter o padrão

"""
Conjunto de funções padrão

    Func(+, 2),
    Func(-, 2),
    Func(myprod, 2),
    Func(mydiv, 2),

    Func(mysquare, 1),
    Func(mysqrt, 1),
    Func(myexp, 1),
    Func(mylog, 1)
"""
defaultFunctionSet = Func[ # Definindo um conjunto de funções padrão (mesmas utilizadas em Parameter identification)
    Func(+, 2),
    Func(-, 2),
    Func(myprod, 2),
    Func(mydiv, 2),

    Func(mysquare, 1),
    Func(mysqrt, 1),
    Func(myexp, 1),
    Func(mylog, 1),

    #Func(mysin, 1),
    #Func(mycos, 1),
    #Func(mysqrtabs, 1),
]

"""
Conjunto de constantes padrão

    Const(3.1415),
    Const(1.0),
    Const(-1.0)
"""
defaultConstSet = Const[
    Const(3.1415),
    Const(1.0),
    Const(-1.0)
]

"""
Conjunto de ERC padrão

    ERC(-1.0, 1.0)

"""
defaultERCSet = ERC[
    ERC(-1.0, 1.0)
]