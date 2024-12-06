
# We could make this a generated function as well, but since the header
# is only printed once at the beginning, the additional time needed for
# runtime introspection is worth the reduction in complexity.
"""
$(SIGNATURES)

Print a header for an observation type `stats_t` to `output` using field separator `FS`, name separator `NS` and line separator `LS`.
"""
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
"""
$(SIGNATURES)

Print results stored in `stats` to `output` using field separator `FS` and line separator `LS`.
"""
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

