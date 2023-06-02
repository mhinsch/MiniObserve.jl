push!(LOAD_PATH, "../src")

using Documenter, MiniObserve

cp("../README.md", "src/README.md")

makedocs(sitename="MiniObserve.jl",
	format   = Documenter.HTML(
	    prettyurls = get(ENV, "CI", nothing) == "true",
	    warn_outdated = true,
	    collapselevel = 1
	    ),
	modules = [Observation, StatsAccumulator],
	pages=["Home" => "index.md",
			"Readme" => "README.md",
			"Observation" => "obs.md",
			"Stats Accumulators" => "stats.md"])
			
deploydocs(
    repo = "github.com/mhinsch/MiniObserve.jl.git",
    )
