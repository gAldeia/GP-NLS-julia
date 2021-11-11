using Documenter

# Isso assume que o pacote pode ser encontrado pela Julia
using GP_NLS

makedocs(
    #source="GP_NLS/src",
    sitename="GP_NLS",
    repo="https://github.com/gAldeia/GP-NLS-julia",
    build="../docs",
    pages = [
        "index.md",
        "Tipos e funções acessíveis" => "Exported.md",
        "Todas as implementações" => [
            "Conteúdos dos nós" => "Nodes.md",
            "Estrutura das árvores" => "Trees.md",
            "Funções de utilidade" => "Utils.md",
            "Avaliação de árvores" => "Evaluation.md",
            "Inicialização de população" => "Initialization.md",
            "Algoritmo evolutivo" => "Evolutionary.md",
            "Otimização não-linear" => "LsqOptimization.md",
        ]
    ]    
)

