push!(LOAD_PATH, "../src")

using Documenter, MiniObserve

#cp("../README.md", "src/README.md")

makedocs(sitename="MiniObserve.jl",
	format   = Documenter.HTML(
	    prettyurls = get(ENV, "CI", nothing) == "true",
	    warn_outdated = true,
	    collapselevel = 1
	    ),
	modules = [Observation, StatsAccumulatorBase, StatsAccumulator],
	pages=[ "Introduction" => "README.md",
			"Observation" => "obs.md",
			"StatsAccumulatorBase" => "statsbase.md",
			"Stats Accumulators" => "stats.md",
			"Index" => "index.md"])
			
deploydocs(
    repo = "github.com/mhinsch/MiniObserve.jl.git",
    )
