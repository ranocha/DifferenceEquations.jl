using ChainRulesTestUtils, DifferenceEquations, Distributions, LinearAlgebra, Test, Zygote
using DelimitedFiles
using FiniteDiff: finite_difference_gradient

# joint case
function joint_likelihood_1(A, B, C, u0, noise, observables, D; kwargs...)
    problem = LinearStateSpaceProblem(A, B, C, u0, (0, size(noise, 2)), Val(false); # doesn't allocate buffers for kalman filter
                                      obs_noise = MvNormal(Diagonal(abs2.(D))), noise, observables,
                                      kwargs...)
    return solve(problem, NoiseConditionalFilter(); save_everystep = false).loglikelihood
end

# Kalman only
function kalman_likelihood(A, B, C, u0, observables, D; kwargs...)
    problem = LinearStateSpaceProblem(A, B, C, MvNormal(diagm(ones(length(u0)))),
                                      (0, size(observables, 2)); noise = nothing,
                                      obs_noise = MvNormal(Diagonal(abs2.(D))), observables,
                                      kwargs...)
    return solve(problem, KalmanFilter(); save_everystep = false).loglikelihood
end

# Matrices from RBC
A_rbc = [0.9568351489231076 6.209371005755285; 3.0153731819288737e-18 0.20000000000000007]
B_rbc = reshape([0.0; -0.01], 2, 1) # make sure B is a matrix
C_rbc = [0.09579643002426148 0.6746869652592109; 1.0 0.0]
D_rbc = [0.1, 0.1]
u0_rbc = zeros(2)

path = joinpath(pkgdir(DifferenceEquations), "test", "data")
file_prefix = "RBC"
observables_rbc = readdlm(joinpath(path, "$(file_prefix)_observables.csv"), ',')' |> collect
noise_rbc = readdlm(joinpath(path, "$(file_prefix)_noise.csv"), ',')' |> collect

# Data and Noise
T = 5
observables_rbc = observables_rbc[:, 1:T]
noise_rbc = noise_rbc[:, 1:T]

@testset "linear rbc joint likelihood" begin
    @test joint_likelihood_1(A_rbc, B_rbc, C_rbc, u0_rbc, noise_rbc, observables_rbc, D_rbc) ≈
          -690.9407412360038
    @inferred joint_likelihood_1(A_rbc, B_rbc, C_rbc, u0_rbc, noise_rbc, observables_rbc, D_rbc) # would this catch inference problems in the solve?
    test_rrule(Zygote.ZygoteRuleConfig(),
               (args...) -> joint_likelihood_1(args..., observables_rbc, D_rbc), A_rbc, B_rbc,
               C_rbc, u0_rbc, noise_rbc; rrule_f = rrule_via_ad, check_inferred = false)
end

@testset "linear rbc joint likelihood preallocated" begin
    cache = LinearStateSpaceProblemCache{Float64}(size(A_rbc, 1), size(B_rbc, 2),
                                                  size(observables_rbc, 1),
                                                  size(observables_rbc, 2) + 1, Val(false)) # do not allocate for kalman
    @test joint_likelihood_1(A_rbc, B_rbc, C_rbc, u0_rbc, noise_rbc, observables_rbc, D_rbc;
                             cache) ≈ -690.9407412360038
    @inferred joint_likelihood_1(A_rbc, B_rbc, C_rbc, u0_rbc, noise_rbc, observables_rbc, D_rbc;
                                 cache)
    f_cache_grad = gradient((args...) -> joint_likelihood_1(args..., observables_rbc, D_rbc; cache),
                            A_rbc, B_rbc, C_rbc, u0_rbc, noise_rbc)
    f_grad = gradient((args...) -> joint_likelihood_1(args..., observables_rbc, D_rbc), A_rbc,
                      B_rbc, C_rbc, u0_rbc, noise_rbc)
    @test all(f_cache_grad .== f_grad) # for some reason the test_rrule doesn't like the cache
end

@testset "linear rbc kalman likelihood" begin
    @test kalman_likelihood(A_rbc, B_rbc, C_rbc, u0_rbc, observables_rbc, D_rbc) ≈
          -607.3698273765538
    @inferred kalman_likelihood(A_rbc, B_rbc, C_rbc, u0_rbc, observables_rbc, D_rbc) # would this catch inference problems in the solve?
    test_rrule(Zygote.ZygoteRuleConfig(),
               (args...) -> kalman_likelihood(args..., observables_rbc, D_rbc), A_rbc, B_rbc, C_rbc,
               u0_rbc; rrule_f = rrule_via_ad, check_inferred = false)
end

@testset "linear rbc kalman likelihood preallocated" begin
    cache = LinearStateSpaceProblemCache{Float64}(size(A_rbc, 1), size(B_rbc, 2),
                                                  size(observables_rbc, 1),
                                                  size(observables_rbc, 2) + 1)
    @test kalman_likelihood(A_rbc, B_rbc, C_rbc, u0_rbc, observables_rbc, D_rbc; cache) ≈
          -607.3698273765538
    @inferred kalman_likelihood(A_rbc, B_rbc, C_rbc, u0_rbc, observables_rbc, D_rbc; cache)
    f_cache_grad = gradient((args...) -> kalman_likelihood(args..., observables_rbc, D_rbc; cache),
                            A_rbc, B_rbc, C_rbc, u0_rbc)
    f_grad = gradient((args...) -> kalman_likelihood(args..., observables_rbc, D_rbc), A_rbc, B_rbc,
                      C_rbc, u0_rbc)
    @test all(f_cache_grad .== f_grad) # for some reason the test_rrule doesn't like the cache

    # tweak and reuse the cache
    observables_rbc_2 = observables_rbc * 1.05
    f_cache_grad = gradient((args...) -> kalman_likelihood(args..., observables_rbc_2, D_rbc; cache),
                            A_rbc, B_rbc, C_rbc, u0_rbc)
    f_grad = gradient((args...) -> kalman_likelihood(args..., observables_rbc_2, D_rbc), A_rbc,
                      B_rbc, C_rbc, u0_rbc)
    @test all(f_cache_grad .== f_grad) # for some reason the test_rrule doesn't like the cache
end

# Load FVGQ data for checks
path = joinpath(pkgdir(DifferenceEquations), "test", "data")
file_prefix = "FVGQ20"
A_FVGQ = readdlm(joinpath(path, "$(file_prefix)_A.csv"), ',')
B_FVGQ = readdlm(joinpath(path, "$(file_prefix)_B.csv"), ',')
C_FVGQ = readdlm(joinpath(path, "$(file_prefix)_C.csv"), ',')
# D_raw = readdlm(joinpath(path, "$(file_prefix)_D.csv"), ',')
D_FVGQ = ones(6) * 1e-3
observables_FVGQ = readdlm(joinpath(path, "$(file_prefix)_observables.csv"), ',')' |> collect
noise_FVGQ = readdlm(joinpath(path, "$(file_prefix)_noise.csv"), ',')' |> collect
u0_FVGQ = zeros(size(A_FVGQ, 1))

@testset "linear FVGQ joint likelihood" begin
    @test joint_likelihood_1(A_FVGQ, B_FVGQ, C_FVGQ, u0_FVGQ, noise_FVGQ, observables_FVGQ,
                             D_FVGQ) ≈ -1.4648817357717388e9
    @inferred joint_likelihood_1(A_FVGQ, B_FVGQ, C_FVGQ, u0_FVGQ, noise_FVGQ, observables_FVGQ,
                                 D_FVGQ)
    test_rrule(Zygote.ZygoteRuleConfig(),
               (args...) -> joint_likelihood_1(args..., observables_FVGQ, D_FVGQ), A_FVGQ, B_FVGQ,
               C_FVGQ, u0_FVGQ, noise_FVGQ; rrule_f = rrule_via_ad, check_inferred = false)
end

@testset "linear FVGQ Kalman" begin
    # Note: set rtol to be higher than the default case because of huge gradient numbers
    @test kalman_likelihood(A_FVGQ, B_FVGQ, C_FVGQ, u0_FVGQ, observables_FVGQ, D_FVGQ) ≈
          -108.52706300389917
    gradient((args...) -> kalman_likelihood(args..., observables_FVGQ, D_FVGQ), A_FVGQ, B_FVGQ,
             C_FVGQ, u0_FVGQ)

    # TODO: this is not turned on because the numbers explode.  Need better unit test data to be interior
    # test_rrule(Zygote.ZygoteRuleConfig(), (args...) -> kalman_likelihood(args..., observables, D),
    #            A, B, C, u0; rrule_f = rrule_via_ad, check_inferred = false, rtol = 1e-5)
end

@testset "linear FVGQ kalman likelihood preallocated" begin
    cache = LinearStateSpaceProblemCache{Float64}(size(A_FVGQ, 1), size(B_FVGQ, 2),
                                                  size(observables_FVGQ, 1),
                                                  size(observables_FVGQ, 2) + 1)
    @test kalman_likelihood(A_FVGQ, B_FVGQ, C_FVGQ, u0_FVGQ, observables_FVGQ, D_FVGQ; cache) ≈
          -108.52706300389917
    @inferred kalman_likelihood(A_FVGQ, B_FVGQ, C_FVGQ, u0_FVGQ, observables_FVGQ, D_FVGQ; cache)
    f_cache_grad = gradient((args...) -> kalman_likelihood(args..., observables_FVGQ, D_FVGQ; cache),
                            A_FVGQ, B_FVGQ, C_FVGQ, u0_FVGQ)
    f_grad = gradient((args...) -> kalman_likelihood(args..., observables_FVGQ, D_FVGQ), A_FVGQ,
                      B_FVGQ, C_FVGQ, u0_FVGQ)
    @test all(f_cache_grad .== f_grad) # for some reason the test_rrule doesn't like the cache vs. no-cache cases.
end
