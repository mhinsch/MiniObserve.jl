"""

This module implements the observation logic itself.

"""
module Observation

export print_header, @observe, log_results

using ..StatsAccumulatorBase: add! 

using MacroTools
using MacroTools: prewalk

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
stat_names(::Type{T}) where {T} = fieldnames(result_type(T))

# We could make this a generated function as well, but since the header
# is only printed once at the beginning, the additional time needed for
# runtime introspection is worth the reduction in complexity.
"Print a header for an observation type `stats_t` to `output` using field separator `FS`, name separator `NS` and line separator `LS`."
function print_header(output, stats_t; FS="\t", NS="_", LS="\n")
	fn = fieldnames(stats_t)
	ft = fieldtypes(stats_t)

	for (i, (name, typ)) in enumerate(zip(fn, ft))
		if typ <: NamedTuple
			# aggregate stat
			header(output, string(name), string.(fieldnames(typ)), FS, NS)
		else
			# single stat
			print(output, string(name))
		end

		if i < length(fn)
			print(output, FS)
		end
	end

	print(output, LS)
end

# print header for aggregate stat
function header(out, stat_name, stat_names, FS, NS)
	@assert length(stat_names) > 0

	print(out, join((stat_name * NS) .* stat_names, FS))
end

# It's quite possibly overkill to make this a generated function, but we
# don't want anybody accusing us of wasting CPU cycles.
"Print results stored in `stats` to `output` using field separator `FS` and line separator `LS`."
@generated function log_results(out, stats; FS="\t", LS="\n")
	fn = fieldnames(stats)
	ft = fieldtypes(stats)

	fn_body = Expr(:block)

	# all fields of stats
	for (i, (name, typ)) in enumerate(zip(fn, ft))
		# aggregate stats
		if typ <: NamedTuple
			# go through all elements of stats.name
			for (j, tname) in enumerate(fieldnames(typ))
				push!(fn_body.args, :(print(out, stats.$name.$tname)))
				if j < length(fieldnames(typ))
					push!(fn_body.args, :(print(out, FS)))
				end
			end
		# single values
		else
			push!(fn_body.args, :(print(out, stats.$name)))
		end

		if i < length(fn)
			push!(fn_body.args, :(print(out, FS)))
		end
	end

	push!(fn_body.args, :(print(out, LS)))

	fn_body
end


@inline function add_result_to_accs!(result, acc)
	add!(acc, result)
	nothing
end

@inline function add_result_to_accs!(result, accs...)
	foreach(a -> add!(a, result), accs)
	nothing
end


# process a single stats declaration (@record)	
function process_single(name, typ, expr)
	# no type specified, default to float
	if typ == nothing
		typ = :Float64
	end

	tmp_name = gensym("tmp")
	:($tmp_name = $expr)

	:($name :: $(esc(typ))),	# type
		:($tmp_name = $expr),	# body
		:($tmp_name)					# result constructor
end

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


# code to declare stat property in stats struct
# creates a single named tuple type from all result types of all stats
function data_struct_elements(statname, stattypes)
    sname = Symbol(statname)
    prop_code = :($sname :: joined_named_tuple_T())
    for t in stattypes
        # not a constructor call
        if ! @capture(t, typ_(args__))
            typ = t
        end

        push!(prop_code.args[2].args, :($(esc(:result_type))($(esc(typ)))))
    end

    prop_code
end


error_stat_syntax() = error("expected: [@if cond] @stat(<NAME>, <STAT> {, <STAT>}) <| <EXPR>")



function process_expression!(ex, stats_type, stats_results, acc_temp_vars)
    # local declaration of accumulator objects, goes to beginning of function
	temp_vars_code = []
		
	typ = :Float64
	
	if @capture(ex, @record(name_String, expr_)) || @capture(ex, @record(name_String, typ_, expr_)) 
		stats_type_code, ana_body_code, stats_results_code = process_single(Symbol(name), typ, expr)
		
	#elseif ex.args[1] == Symbol("@record") 
	#	error("expecting: @record <NAME> [<TYPE>] <EXPR>")

	elseif @capture(ex, @stat(statname_String, stattypes__) <| expr_) 
        # data struct
        stats_type_code = data_struct_elements(statname, stattypes)
        
		# adding data to accumulators, replaces macro in place
		ana_body_code = :(MiniObserve.Observation.add_result_to_accs!($expr))
		
		# expression that merges all results for this stat into single named tuple,
		# part of function return expression
		stats_results_code = length(stattypes) > 1 ? :(merge()) : :(identity())
		
		# all stats for this specific @stat term
		for (j, stattype) in enumerate(stattypes)
			# declaration of accumulator
			vname = gensym("stat")
            # goes into main body (outside of loop)
            if @capture(stattype, typ_(args__))
                # paste in constructor expression
                push!(temp_vars_code, :($vname = $stattype))
            else
                # create constructor call
                push!(temp_vars_code, :($vname = $stattype()))
            end
            
            # add accumulater to add call
            push!(ana_body_code.args, :($vname))
			# add to named tuple argument of constructor call
			push!(stats_results_code.args, :(MiniObserve.Observation.to_named_tuple(results($vname))))
		end
    # everything else is copied verbatim
	else
		return ex
	end

	# add code to respective bits
	push!(stats_type.args[3].args, stats_type_code)
	append!(acc_temp_vars, temp_vars_code)
	push!(stats_results.args, stats_results_code)
	ana_body_code
end


""" 

@observe(statstype, user_arg1 [, user_arg2...], declarations)

Generate a full analysis and logging suite for a set of data structures.

Given a declaration

```Julia
@observe Data model stat1 stat2 begin
	@record "time"      model.time
	@record "N"     Int length(model.population)

	@for ind in model.population begin
		@stat("capital", MaxMinAcc{Float64}, MeanVarAcc{FloatT}) <| ind.capital
		@stat("n_alone", CountAcc)           <| has_neighbours(ind)
	end

	@record s1			stat1
	@record s2			stat1 * stat2
end
```

a type Data will be generated that provides (at least) the following members:

```Julia
struct Data
	time :: Float64
	N :: Int
	capital :: @NamedTuple{max :: Float64, min :: Float64, mean :: Float64, var :: Float64}
	n_alone :: @NamedTuple{N :: Int}
	s1 :: Float64
	s2 :: Float64
end
```

The macro will also create a method for `observe(::Type{Data), model...)` that will perform the required calculations and returns a `Data` object. Use `print_header` to print a header for the generated type to an output and `log_results` to print the content of a data object.
"""
macro observe(tname, args_and_decl...)
	observe_syntax = "@observe <type name> <user arg> [<user args> ...] <declaration block>"

	if typeof(tname) != Symbol
		error("usage: $observe_syntax")
	end

	if length(args_and_decl) < 2
		error("usage: $observe_syntax")
	end

	decl = args_and_decl[end]

	if typeof(decl) != Expr || decl.head != :block
		error("usage: $observe_syntax")
	end

	stats_type = :(struct $(esc(tname)); end)
	
	ana_func = :(function observe(::$(:Type){$(tname)}, 
			$(args_and_decl[1:end-1]...)) end)

	ana_body = ana_func.args[2].args

	stats_results = :($tname())

	syntax = "single or population stats declaration expected:\n" *
		"\t@for <NAME> in <EXPR> <BLOCK> |" *
		"\t@record <NAME> <EXPR> |" *
		"\t@record <NAME> <TYPE> <EXPR>"
		
	acc_temp_vars = []
		
	fn_body = prewalk(ex -> process_expression!(ex, stats_type, stats_results, acc_temp_vars), decl)
	
	append!(ana_body, acc_temp_vars)
	append!(ana_body, fn_body.args)
	push!(ana_body, stats_results)

	ret = Expr(:block)
	push!(ret.args, stats_type)
	push!(ret.args, :($(esc(ana_func))))

	ret
end
	# go through declaration expression by expression
	# each expression is translated into three bits of code:
	# * additional fields for the stats type
	# * additional code to run during the analysis
	# * additional arguments for the stats object constructor call
	#=lines = rmlines(decl).args
	for (i, line) in enumerate(lines)
		# single stat
		if line.args[1] == Symbol("@record")
			typ = nothing
			@capture(line, @record(name_String, expr_)) || 
				@capture(line, @record(name_String, typ_, expr_)) ||
				error("expecting: @record <NAME> [<TYPE>] <EXPR>")
			stats_type_c, ana_body_c, stats_constr_c = 
				process_single(Symbol(name), typ, expr)

		# aggregate stat
		elseif line.args[1] == Symbol("@for")
			@capture(line, @for var_Symbol in expr_ begin block_ end) ||
				error("expecting: @for <NAME> in <EXPR> <BLOCK>")
			stats_type_c, ana_body_c, stats_constr_c = 
				process_aggregate(var, expr, block)

        # everything else is copied verbatim
		else
            stats_type_c = []
            stats_constr_c = []
            ana_body_c = [esc(line)]
		end

		# add code to respective bits
		append!(ana_func.args[2].args, ana_body_c)
		append!(stats_type.args[3].args, stats_type_c)
		append!(stats_constr.args, stats_constr_c)
	end
=#
	# add constructor call as last line of analysis function

end	# module
