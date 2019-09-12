#This file contains a list of the currently implemented likelihood function

abstract type Likelihood end

include("bernoulli.jl")
include("exponential.jl")
include("gaussian.jl")
include("studentT.jl")
include("poisson.jl")
include("binomial.jl")

#————————————————————————————————————————————
#Predict observations at test locations

""" Computes the predictive mean and variance given a Gaussian distribution for f using quadrature"""
function predict_obs(lik::Likelihood, fmean::AbstractVector, fvar::AbstractVector)
    n_gaussHermite = 20
    nodes, weights = gausshermite(n_gaussHermite)
    weights /= sqrtπ
    f = fmean .+ sqrt.(2*fvar)*nodes'

    mLik = Array{Float64}(undef, size(f)); vLik = Array{Float64}(undef, size(f));
    @inbounds for i in 1:n_gaussHermite
        fi = view(f, :, i)
        mLik[:, i] = mean_lik(lik, fi)
        vLik[:, i] = var_lik(lik, fi)
    end
    μ = mLik*weights
    σ² = (vLik + mLik.^2)*weights - μ.^2
    return μ, σ²
end

""" Computes the integral ∫log p(y|f)*q(f)df using quadrature using to calculate the ELBO in variational inference"""
function expect_dens(lik::Likelihood, fmean::AbstractVector, fvar::AbstractVector, y::AbstractVector)
    n_gaussHermite = 20
    nodes, weights = gausshermite(n_gaussHermite)
    weights /= sqrtπ
    f = fmean .+ sqrt.(2*fvar)*nodes'
    lpred = Array{Float64}(undef, size(f));
    @inbounds for i in 1:n_gaussHermite
        fi = view(f, :, i)
        lpred[:,i] = log_dens(lik, fi, y)
    end
    return lpred*weights
end

function dv_var_exp(ll::PoisLik, y::Number, m::Number, V::Number)
    # return gradient(x -> var_exp(ll, y, m, x), V)[1]
    return -0.5*exp(m + V/2)
end
