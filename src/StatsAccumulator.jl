module StatsAccumulator

export CountAcc, MeanVarAcc, add!, results, result_type, MaxMinAcc, HistAcc, SumAcc

using DocStringExtensions


# per default the struct itself is assumed to contain the results (see e.g. min/max)

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


### CountAcc

"Count number of true values in input. Results are returned as `(;n)`."
mutable struct CountAcc
	n :: Int
end

CountAcc() = CountAcc(0)

add!(acc :: CountAcc, cond) = cond ? acc.n += 1 : 0


### SumAcc

"Calculate sum of input. Results are returned as `(;n)`."
mutable struct SumAcc{T}
	n :: T
end

SumAcc{T}() where {T} = SumAcc(T(0))

add!(acc :: SumAcc, x) = acc.n += x


### MeanVar

"Calculate mean and variance of input. Results are given as `(;mean, var)`"
mutable struct MeanVarAcc{T}
	sum :: T
	sum_sq :: T
	n :: Int
end

MeanVarAcc{T}() where {T} = MeanVarAcc(T(0), T(0), 0)

function add!(acc :: MeanVarAcc{T}, v :: T) where {T}
	acc.sum += v
	acc.sum_sq += v*v
	acc.n += 1
end

results(acc :: MeanVarAcc{T}) where {T} = 
	(mean = acc.sum / acc.n, var = (acc.sum_sq - acc.sum*acc.sum/acc.n) / (acc.n - 1))

result_type(::Type{MeanVarAcc{T}}) where {T} = @NamedTuple{mean::T, var::T}
	


#mutable struct MeanVarAcc2{T}
#	m :: T
#	m2 :: T
#	n :: Int
#end
#
#MeanVarAcc2{T}() where T = MeanVarAcc2(T(0), T(0), 0)
#
#function add!(acc :: MeanVarAcc2{T}, v :: T) where T
#	delta = v - acc.m
#	acc.n += 1
#	delta_n = delta / acc.n
#	acc.m += delta_n
#	acc.m2 += delta * (delta - delta_n)
#end
#
#result(acc :: MeanVarAcc2{T}) where {T} = acc.m, acc.m2 / acc.n

### MaxMin

"Keep track of maximum and minimum of input. Results are returned as `(;max, min)`."
mutable struct MaxMinAcc{T}
	max :: T
	min :: T
end

MaxMinAcc{T}() where {T} = MaxMinAcc(typemin(T), typemax(T))

function add!(acc :: MaxMinAcc{T}, v :: T) where {T}
	acc.max = max(acc.max, v)
	acc.min = min(acc.min, v)
end


### HistAcc

"Track a histogram of input values. Results are returned as a `(;bins::Vector{Int})`."
mutable struct HistAcc{T}
    bins :: Vector{Int}
    min :: T
    max :: T
    width :: T
    keep_min :: Bool
    keep_max :: Bool
end

"""
$(SIGNATURES)

Construct a histogram accumulator. 

Arguments:

* `min` - minimum value [`T(0)`]
* `width` - bin size [`T(1)`]
* `max` - maximum value. Set lower than or equal to `min` to let the histogram adjust size automatically. [`min`]
* `count_below_min` - whether values lower than `min` are ignored or counted in the first bin [`false`]
* `count_above_max` - whether values larger than `max` are ignored or counted in the last bin [`false`]
"""
HistAcc(min::T = T(0), width::T = T(1), max::T = min; 
        count_below_min = false, count_above_max = false) where {T} = 
    HistAcc{T}(
               max <= min ? T[] : zeros(T, find_bin(min, width, max)), 
               min, max, width, count_below_min, count_above_max)

find_bin(min, width, v) = floor(Int, (v - min) / width) + 1

function add!(acc :: HistAcc{T}, v :: T) where {T}
	@assert !isnan(v)
	
    if v < acc.min
        # don't count values that are too small
        if ! acc.keep_min
            return acc
        end
        v = acc.min
    elseif acc.min < acc.max < v
        # don't count values that are too big
        if ! acc.keep_max
            return acc
        end
        v = acc.max
    end

    bin = find_bin(acc.min, acc.width, v)
    n = length(acc.bins)
    if bin > n
        sizehint!(acc.bins, bin)
        for i in (n+1):bin
            push!(acc.bins, 0)
        end
    end

    acc.bins[bin] += 1

    acc
end

results(acc::HistAcc) = (;bins = acc.bins)

result_type(::Type{HistAcc}) = @NamedTuple{bins::Vector{Int}}


# does not work with results/result_type, maybe rework as tuples?

#struct AccList
#	list :: Vector{Any}
#end
#
#AccList() = AccList([])
#
#function add!(al :: AccList, v :: T) where {T}
#	for a in al.list
#		add!(a, v)
#	end
#end

end # module
