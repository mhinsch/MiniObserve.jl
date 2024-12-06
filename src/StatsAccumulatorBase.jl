"""
Accumulators can be used to calculate aggregate statistics over sets of elements. In order to be able to work with `@observe.@stat` an accumulator has to implement the following functions:

* `add!(acc, dat)` - add a datum to the accumulator. This function has no default implementation.
* `result_type(T)` - the type of the result the accumulator generates. Per default it is assumed that this is identical to the accumulator type itself.
* `result(acc)` - obtain the current result from the accumulator. Returns the accumulator object itself by default.
"""
module StatsAccumulatorBase
	
export results, result_type, add!

using DocStringExtensions

"""

```Julia
add!(accumulator, value)
```


Add a new value to a given accumulator. This function needs to be implemented for new accumulator types.
"""
function add! end

"""
$(SIGNATURES)

Returns the type of the results of accumulator `T`. 

Per default the accumulator type itself is assumed to form the result. Overload for custom result types.
"""
result_type(::Type{T}) where {T} = T

"""
$(SIGNATURES)

Return the results of an accumulator.

Per default it is assumed that the accumulator type contains the result. Overload for custom result types. 

"""
results(t :: T) where {T} = t
	
end
