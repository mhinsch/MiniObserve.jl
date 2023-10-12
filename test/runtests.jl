include("../src/MiniObserve.jl")
using .MiniObserve

using Test

struct Agent
	capital :: Float64
	n :: Int
end

has_neighbours(a) = a.n > 0

struct Model
	time :: Float64
	population :: Vector{Agent}
end

function Model()
	t = 10.0
	p = [Agent(0.0, 2), Agent(2.0, 0), Agent(1.0, 10)]

	Model(t, p)
end


@observe Data model begin
	@record "time"      model.time
	@record "N"     Int length(model.population)

	@for ind in model.population begin
	    @stat("capital", MaxMinAcc{Float64}) <| ind.capital
		@stat("n_alone", CountAcc)           <| !has_neighbours(ind)
        @stat("all_capital", SumAcc{Float64})  <| ind.capital
	end
end


@testset "Analysis" begin

m = Model()
result = observe(Data, m)

@test typeof(result) == Data
@test result.time == m.time
@test result.N == length(m.population)
@test result.capital.max == 2.0
@test result.capital.min == 0.0
@test result.n_alone.n == 1
@test result.all_capital.n == 3.0

end


@testset "Output" begin

m = Model()
result = observe(Data, m)

io = IOBuffer()

print_header(io, Data)
@test String(take!(io)) == "time\tN\tcapital_max\tcapital_min\tn_alone_n\tall_capital_n\n"

log_results(io, result)
@test String(take!(io)) == "10.0\t3\t2.0\t0.0\t1\t3.0\n"

end


@observe Data2 model user1 begin
	@record "time"      model.time
	@record "N"     Int length(model.population)

	@for ind in model.population begin
	    @stat("capital", MaxMinAcc{Float64}) <| ind.capital
		@stat("n_alone", CountAcc)           <| !has_neighbours(ind)
	end

	@record "user"		user1
end


@testset "User data" begin

m = Model()
result = observe(Data2, m, 42)

@test typeof(result) == Data2
@test result.time == m.time
@test result.N == length(m.population)
@test result.capital.max == 2.0
@test result.capital.min == 0.0
@test result.n_alone.n == 1
@test result.user == 42.0

end

const run_count = [0]

@observe Data3 model begin
	@for ind in model.population begin
	    @if ind.capital > 0 @stat("count", CountAcc) <| (run_count[1]+=1; ind.n==10)
	end
end


@testset "if" begin
	m = Model()
	result = observe(Data3, m)
	
	@test run_count[1] == 2
	@test result.count.n == 1
end

