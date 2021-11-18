using Documenter, GP_NLS

makedocs(
    #source="GP_NLS/src",
    sitename="GP_NLS",
    repo="https://github.com/gAldeia/GP-NLS-julia",
    build="../docs",
    pages = [
        "GP_NLS in Julia" => "index.md",
        "Documentation" => [
            "Data Types" => "exported/datatypes.md",
            "Default sets" => "exported/defaultsets.md",
            "Auxiliary Functions" => "exported/auxiliaryfunctions.md",
            "Genetic Programming algorithm" => "exported/gp.md"
        ],
        "Auxiliary functions (unexported)" => "unexported.md"
    ],
    doctest = true
)

