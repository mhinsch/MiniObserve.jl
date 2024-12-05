"""

This module implements the observation logic itself.

"""
module Observation

export print_header, @observe, log_results

using ..StatsAccumulatorBase: add! 

using MacroTools
using MacroTools: prewalk


include("utils.jl")
include("file_io.jl")


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

# process a single expression in the AST handed over to the observe macro
# returns the expression unaltered unless @record or @stat is encountered
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

Observe expects a (new) type name, a number of user arguments and a block of declarations. It will generate a function `observe` that takes the user arguments and returns an instance of the data type. The declaration block will be copied verbatim to the body of the `observe` function, but all occurences of the "pseudo-macros" `@record` and `@stat` will be replaced with corresponding analysis code. 

The newly defined result data type will contain properties for all calculated results.

So, given a declaration

```Julia
@observe Data model stat1 stat2 begin
	@record "time"      model.time
	@record "N"     Int length(model.population)

	for ind in model.population 
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

The macro will also create a method `observe(::Type{Data), model, stat1, stat2)` that will perform the required calculations and returns a `Data` object. 

Use `print_header` to print a header for the generated type to an output and `log_results` to print the content of a data object.
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

end	# module
