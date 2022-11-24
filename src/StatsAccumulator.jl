module StatsAccumulator

export CountAcc, MeanVarAcc, add!, results, result_type, MaxMinAcc, HistAcc, SumAcc



# per default the struct itself is assumed to contain the results (see e.g. min/max)

"type of results of accumulator `T`, overload as needed"
result_type(::Type{T}) where {T} = T

"results, overload as needed"
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
    width :: T
end

"Construct a histogram accumulator. Provide minimum value and bin size as `min` and `width`."
HistAcc(min::T = T(0), width::T = T(1)) where {T} = HistAcc{T}([], min, width)

function add!(acc :: HistAcc{T}, v :: T) where {T}
    if v < acc.min
        return acc
    end

    bin = floor(Int, (v - acc.min) / acc.width) + 1
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
