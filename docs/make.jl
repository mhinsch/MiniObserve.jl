push!(LOAD_PATH, "../src")

using Documenter, MiniObserve

makedocs(sitename="MiniObserve Documentation", pages=["Home" => "index.md"])
