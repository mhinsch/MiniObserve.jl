# Introduction

Given a declaration

```Julia
@observe Data model user1 user2 begin
	@record "time"      model.time
	@record "N"     Int length(model.population)

	@for ind in model.population begin
		@stat("capital", MaxMinAcc{Float64}, MeanVarAcc{FloatT}) <| ind.capital
		@stat("n_alone", CountAcc)           <| has_neighbours(ind)
	end

	@record u1			user1
	@record u2			user1 * user2
end
```

a type Data will be generated that provides (at least) the following members:

```Julia
struct Data
	time :: Float64
	N :: Int
	capital :: @NamedTuple{max :: Float64, min :: Float64, mean :: Float64, var :: Float64}
	n_alone :: @NamedTuple{N :: Int}
	u1 :: Float64
	u2 :: Float64
end
```

The macro will also create a method for `observe(::Type{Data), model...)` that will perform the required calculations and returns a `Data` object. Use `print_header` to print a header for the generated type to an output and `log_results` to print the content of a data object.

## Reference

```@index
```
