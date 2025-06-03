"obtain a named tuple type with the same field types and names as `struct_T`"
tuple_type(struct_T) = NamedTuple{fieldnames(struct_T), Tuple{fieldtypes(struct_T)...}}

"construct a named tuple from `x`"
@generated function to_named_tuple(x)
	if x <: NamedTuple
		return :x
	end

	# constructor call
	tuptyp = Expr(:quote, tuple_type(x))
	
	# constructor arguments
	tup = Expr(:tuple)
	for i in 1:fieldcount(x)
		push!(tup.args, :(getfield(x, $i)) )
	end
	
	# both put together
	:($tuptyp($tup))
end


"translate accumulator types into prefixes for the header (e.g. min, max, etc.)"
stat_names(::Type{T}) where {T} = fieldnames(StatsAccumulatorBase.result_type(T))


# it would be much nicer to use a generated function for this, but
# unfortunately we are already operating on types
"concatenate named tuple and/or struct types into one single named tuple"
function joined_named_tuple_T(types...)
	ns = Expr(:tuple)
	ts = Expr(:curly)
	push!(ts.args, :Tuple)
	
	for t in types
		fnames = fieldnames(t)
		ftypes = fieldtypes(t)

		append!(ns.args, QuoteNode.(fnames))
		append!(ts.args, ftypes)
	end
	
	ret = :(NamedTuple{})
	push!(ret.args, ns)
	push!(ret.args, ts)

	eval(ret)
end

