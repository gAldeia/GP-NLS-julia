using Test

using LinearAlgebra
using LsqFit
using Random
using LinearAlgebra
using Statistics

using GP_NLS


# Várias verificações são dispensáveis por conta da verificação de tipos do compilador

@testset "Verificação em Nodes.jl" begin
    @testset "Nós de funções" begin
        a = Float64[1., 2., 3.]

        for f in defaultFunctionSet
            # Testar se só temos funções dentro do conjunto padrão
            @test typeof(f) == Func

            # Testar se recebe um (ou mais) vetor(es) e retorna um único vetor
            @test typeof(f.func([a for _ in 1:f.arity]...)) == Vector{Float64}
        end
    end

    @testset "Geração de constantes com ERC" begin
        # Testar geração de constante pelo ERC (ver se ele gera sempre no range)
        for i in [1.0, 10.0, 100.0]
            aux_ERC = ERC(-i, i)
            for _ in 1:10000
                randVal = Random.rand()*(aux_ERC.u_bound - aux_ERC.l_bound) + aux_ERC.l_bound
                @test -i <= randVal < i
            end
        end
    end

    # Nós de constante são simples, e nós de variáveis também --- são structs apenas
    # para guardar valores. Já as que foram testadas envolvem cálculos que ---
    # caso estejam com bugs --- pode gerar problemas difíceis de encontrar no código.
end


@testset "Verificação em Trees.jl" begin
    # Testar subtipos
    @test typeof(GP_NLS.InternalNode) == typeof(GP_NLS.AbstractNode)
    @test typeof(GP_NLS.TerminalNode) == typeof(GP_NLS.AbstractNode)
    @test typeof(GP_NLS.AbstractNode) == typeof(GP_NLS.AbstractNode)
end


# Vamos criar uma árvore simples e um toy dataset
myprod = GP_NLS.myprod

# Vamos criar esses separados para testes só de constantes e variáveis
x1 = GP_NLS.TerminalNode(Var("x1", 1))
c1 = GP_NLS.TerminalNode(Const(1.0))

test_tree = GP_NLS.InternalNode(Func(-, 2), [
    GP_NLS.InternalNode(Func(myprod, 2), [
        x1,
        c1
    ]),
    GP_NLS.InternalNode(Func(myprod, 2), [
        GP_NLS.TerminalNode(Const(-1.0)),
        GP_NLS.TerminalNode(Var("x2", 2))
    ])
])

toy_X = [
    1.  1.;
    2.  2.;
   -1. -1.;
   -2. -2.
]

toy_y = 1.25*toy_X[:, 1] - -1.25*toy_X[:, 2]


@testset "Verificação em Utils.jl" begin    
    # Testar o evaluate num toy dataset
    @testset "Vetorização do evaluate" begin
        @test evaluate(test_tree, toy_X) == [2., 4., -2., -4.]
        
        # Deve sempre receber uma matriz. No caso de vetor, precisamos do reshape
        @test evaluate(test_tree, reshape(toy_X[1,:], (1, length(toy_X[1,:])))) == [2.] 
        
        # Evaluate em constante deve retornar vetor com mesmo número de observações
        @test evaluate(c1, toy_X) == repeat([c1.terminal.value], size(toy_X, 1))

        # Evaluate na variável deve retornar a coluna da variável
        @test evaluate(x1, toy_X) == toy_X[:, 1]
    end
    
    @testset "Teste de cópia de árvores" begin
        # Pegar referência da string da árvore original
        test_tree_str  = getstring(test_tree)
        test_tree_copy = GP_NLS.copy_tree(test_tree)

        # Mudando os filhos (struct é imutável, mas a lista pode ter elementos modificados)
        test_tree_copy.children[1] = x1

        # Vendo se a referência ainda retorna a mesma string
        @test test_tree_str == getstring(test_tree)

        # Vendo que a cópia modificada é diferente
        @test test_tree_str != getstring(test_tree_copy)

        # Vamos salvar a string da cópia e modificar de novo colocando a árvore original como galho
        test_tree_copy_str = getstring(test_tree_copy)
        test_tree_copy.children[2] = test_tree

        @test test_tree_copy_str != getstring(test_tree_copy)
        @test test_tree_str != getstring(test_tree_copy)

        # Original também não deve ter sido afetada
        @test test_tree_str == getstring(test_tree)
    end

    @testset "Percorrendo árvores" begin
        # Which children: deve funcionar sem dar erro desde que p <= número de nós
        for i in 1:(numberofnodes(test_tree)-1) #subtrair 1 pois são os filhos sem considerar ele
            @test typeof(GP_NLS.which_children(i, test_tree.children)) <:
                  Tuple{Integer, GP_NLS.AbstractNode}
        end
        
        # Get branch, deve funcionar como o anterior
        for i in 1:(numberofnodes(test_tree)-1) #subtrair 1 pois são os filhos sem considerar ele
            @test typeof(GP_NLS.get_branch_at(i, test_tree)) <:
                  GP_NLS.AbstractNode
        end
    end

    # Testando changeat e change_children
    @testset "Modificando subárvores" begin
        # Criar duas cópias de sample_tree e fazer uma ser subárvore da outra
        test_tree_1 = GP_NLS.copy_tree(test_tree)
        test_tree_2 = GP_NLS.copy_tree(test_tree)
        
        # Vamos ver se as referências originais continuam iguais
        test_tree_1_str = getstring(test_tree_1)
        test_tree_2_str = getstring(test_tree_2)

        # Aqui elas devem ser iguais
        @test test_tree_1_str == test_tree_2_str

        # Vamos mudar um nó na profundidade máxima, sabemos que ali irá usar 
        # tanto change_children quanto change_at
        test_tree_changed = GP_NLS.change_at!(
            numberofnodes(test_tree_1)-1,
            test_tree_1,
            test_tree_2
        )

        # Vamos percorrer a nova árvore para ver se não veio quebrada
        for i in 1:(numberofnodes(test_tree_changed)-1) #subtrair 1 pois são os filhos sem considerar ele
            @test typeof(GP_NLS.get_branch_at(i, test_tree_changed)) <:
                  GP_NLS.AbstractNode
        end

        # Vendo se as referências se alteraram
        @test test_tree_1_str == test_tree_2_str
        @test test_tree_1_str == getstring(test_tree_1)
        @test test_tree_2_str == getstring(test_tree_2)

        # Vamos ver se alterações na nova árvore modificam as originais
        test_tree_changed_str = getstring(test_tree_changed)
        test_tree_changed.children[1] = test_tree_1
        test_tree_changed.children[2] = test_tree_2

        @test test_tree_1_str == test_tree_2_str
        @test test_tree_1_str == getstring(test_tree_1)
        @test test_tree_2_str == getstring(test_tree_2)

        @test test_tree_changed_str != getstring(test_tree_changed)
    end

    # depth e numberofnodes são bem simples, não serão testadas
end


@testset "Verificação LsqOptimization.jl" begin
    # Testar find_const_nodes (aqui sabemos quantos nós são)
    test_tree_lsq     = GP_NLS.copy_tree(test_tree)
    test_tree_lsq_str = getstring(test_tree_lsq)

    @testset "Encontrar nós constantes" begin
        const_nodes = GP_NLS.find_const_nodes(test_tree_lsq)
        @test const_nodes[1].terminal.value == 1.0
        @test const_nodes[2].terminal.value == -1.0
    end

    @testset "Testar substituir nós constantes por um novo" begin
        # Testar replace
        test_tree_replace = GP_NLS.replace_const_nodes(
            test_tree_lsq, [2.0, -2.0]
        )

        @test "-(myprod(x1, 2.0), myprod(-2.0, x2))" == getstring(test_tree_replace)

        # Vendo se a referência original continua intacta (deveria)
        @test getstring(test_tree_lsq) == test_tree_lsq_str
    end

    # Testar adaptate (ver número de nós e se tem 2 const a mais, e profundidade)
    @testset "Adaptação da árvore" begin
        test_tree_H, test_tree_p0, test_tree_adapted = GP_NLS.adaptate_tree(test_tree)

        @test numberofnodes(test_tree_adapted) == numberofnodes(test_tree) + 4
        @test depth(test_tree_adapted) == depth(test_tree) + 2
    end
end


@testset "Funções do algoritmo evolutivo" begin
    # Usar os conjuntos padrões para esses testes. OBS: importante prestar atenção
    # no tipo dos terminais: mesmo que não utilizemos todos os símbolos, o array
    # esperado é do tipo Union{Var, Const, ERC} pelos métodos.
    fSet = defaultFunctionSet

    tSet = Vector{Union{Var, WeightedVar, Const, ERC}}(vcat(
        defaultConstSet,
        defaultERCSet,
        Var[Var("x$(i)", i) for i in 1:2],
        WeightedVar[WeightedVar("x$(i)", i) for i in 1:2]
    ))
    
    @testset "Inicializações de árvores PTC2" begin  
        # Vamos gerar controlando por número de nós
        random_pop = GP_NLS.init_pop_PTC2(fSet, tSet, 1, 10, 10, 5000)

        @test size(random_pop, 1) == 5000
          
        for p in random_pop
            # Ver se respeitam restrições (e se foi possível percorrer a árvore sem erro)

            # PTC2 garante no máximo 1 de profundidade além do permitido
            @test 1 <= depth(p) <= 10 + 1

            # PTC2 garante que terá no máximo a maior aridade das funções além do permitido
            @test 1 <= numberofnodes(p) <= 50 + 2
        end        
    end

    @testset "Inicializações de árvores ramped half-half" begin  
        # Vamos gerar controlando por número de nós
        random_pop = GP_NLS.init_pop_ramped(fSet, tSet, 1, 5, 10, 5000)

        @test size(random_pop, 1) == 5000
          
        for p in random_pop
            # Ver se respeitam restrições (e se foi possível percorrer a árvore sem erro)

            # PTC2 garante no máximo 1 de profundidade além do permitido
            @test 1 <= depth(p) <= 5 + 1

            # PTC2 garante que terá no máximo a maior aridade das funções além do permitido
            @test 1 <= numberofnodes(p) <= 50 + 2
        end        
    end

    # Vamos gerar com ramped para o resto (aqui controlamos com profundidade)
    random_pop = GP_NLS.init_pop_ramped(fSet, tSet, 1, 5, 10, 5000)
    
    # Vamos salvar string da população inicial e comparar após crossover e mutação
    random_pop_strs = [getstring(p) for p in random_pop]

    @testset "Inicializações de árvores half-half" begin 
        @test size(random_pop, 1) == 5000

        for p in random_pop
            # Ver se respeitam restrições (e se foi possível percorrer a árvore sem erro)
            @test 1 <= depth(p) <= 5

            # profundidade máxima é 2^(depth)
            @test 1 <= numberofnodes(p) <= 2^5
        end        
    end

    @testset "Testando avaliação do fitness" begin
        for p in random_pop
            # Testar fitness de uma expressão no toy dataset.
            @test typeof(fitness(p, toy_X, toy_y)) <: Real 

            # Testar passando NaN
            @test fitness(p, toy_X, [NaN, 1.0, 1.0, 1.0]) == Inf

            # Testar passando Inf
            @test fitness(p, toy_X, [1.0, 1.0, Inf, 1.0]) == Inf
        end
    end

    @testset "Teste do crossover" begin
        children = [ # Aplicando crossover
            GP_NLS.crossover(
                random_pop[Random.rand(1:end)],
                random_pop[Random.rand(1:end)],
                5,
                2^5
            ) for _ in 1:5000]

        for c in children
            # Ver se respeitam restrições (e se foi possível percorrer a árvore sem erro)
            @test 1 <= depth(c) <= 5
        end

        # Ver se a árvore avalia
        for c in children
            @test typeof(fitness(c, toy_X, toy_y)) <: Real
        end

        # Ver se referência original é alterada
        for (p, p_str) in zip(random_pop, random_pop_strs)
            @test getstring(p) == p_str 
        end
    end

    @testset "Teste da mutação" begin
        children = [
            GP_NLS.mutation!(
                random_pop[i],
                5,              # Profundidade máxima permitida
                2^5,            # Número máximo de nós permitidos
                fSet,
                tSet,
                1.0
            ) for i in 1:5000]

        for c in children
            # Ver se respeitam restrições (e se foi possível percorrer a árvore sem erro)
            #println(getstring(c))
            @test 1 <= depth(c) <= 6 #o PTC2 tem chance de ter 1 a mais de profundidade
        end

        # Ver se a árvore avalia
        for c in children
            @test typeof(fitness(c, toy_X, toy_y)) <: Real
        end

        # Ver se referência original é alterada
        for (p, p_str) in zip(random_pop, random_pop_strs)
            @test getstring(p) == p_str 
        end
    end

    # Torneio não tem muito o que testar, e o GA é complexo e estocástico demais
    # para testes muito específicos.
end