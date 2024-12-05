module StatsAccumulatorBase
	
export results, result_type, add!

using DocStringExtensions


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
