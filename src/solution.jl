"""
    StateSpaceSolution{T1, T2, T3, T4, T5}

Wrapper function containing the observables `z`, 
simulated hidden state `u`, evolution shocks `n`, 
prior variances `P`, and the `likelihood` if
it is available.
"""
struct StateSpaceSolution{T1, T2, T3, T4, T5}
    z::T1 # observables, if relevant
    u::T2 # hidden state, or mean of prior if filtering/estimating
    n::T3 # shocks, if not filtering
    P::T4 # Prior variances
    likelihood::T5  #likelihood of observables
end


# TODO: Need separate solution type for Kalman
#       solves.