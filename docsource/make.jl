using Documenter

using GP_NLS

makedocs(
    #source="GP_NLS/src",
    sitename="GP_NLS",
    repo="https://github.com/gAldeia/GP-NLS-julia",
    build="../docs",
    pages = [
        "GP_NLS" => "index.md",
        "Types and functions exported" => "Exported.md",
        "All source code" => [
            "Node contents" => "Nodes.md",
            "Tree structures" => "Trees.md",
            "Utility functions" => "Utils.md",
            "Tree evaluation" => "Evaluation.md",
            "Population initialization" => "Initialization.md",
            "The GP Algorithm" => "Evolutionary.md",
            "Non-linear optimization" => "LsqOptimization.md",
        ]
    ]    
)

