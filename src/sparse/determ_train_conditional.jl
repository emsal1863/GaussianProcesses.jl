"""
    Deterministic Training Conditional (DTC) covariance strategy.
"""
struct DeterminTrainCondStrat{M<:AbstractMatrix} <: CovarianceStrategy
    inducing::M
end
SubsetOfRegsStrategy(dtc::DeterminTrainCondStrat) = SubsetOfRegsStrategy(dtc.inducing)
function init_precompute(covstrat::DeterminTrainCondStrat, X, y, k)
    SoR = SubsetOfRegsStrategy(covstrat)
    return init_precompute(SoR, X, y, k)
end

function alloc_cK(covstrat::DeterminTrainCondStrat, nobs)
    SoR = SubsetOfRegsStrategy(covstrat)
    return alloc_cK(SoR, nobs)
end
function update_cK!(cK::SubsetOfRegsPDMat, x::AbstractMatrix, kernel::Kernel, 
                    logNoise::Real, data::KernelData, covstrat::DeterminTrainCondStrat)
    SoR = SubsetOfRegsStrategy(covstrat)
    return update_cK!(cK, x, kernel, logNoise, data, SoR)
end
function dmll_kern!(dmll::AbstractVector, gp::GPBase, precomp::SoRPrecompute, covstrat::DeterminTrainCondStrat)
    SoR = SubsetOfRegsStrategy(covstrat)
    return dmll_kern!(dmll, gp, precomp, SoR)
end
function dmll_noise(gp::GPE, precomp::SoRPrecompute, covstrat::DeterminTrainCondStrat)
    SoR = SubsetOfRegsStrategy(covstrat)
    return dmll_noise(gp, precomp, SoR)
end

"""
    Deterministic Training Conditional (DTC) multivariate normal predictions.

    See Quiñonero-Candela and Rasmussen 2005, equations 20b.
        μ_DTC = μ_SoR
        Σ_DTC = Σxx - Qxx + Σ_SoR

    where μ_DTC and Σ_DTC are the predictive mean and covariance
    functions for the Subset of Regressors approximation.
"""
function predictMVN(xpred::AbstractMatrix, xtrain::AbstractMatrix, ytrain::AbstractVector, 
                    kernel::Kernel, meanf::Mean,
                    alpha::AbstractVector,
                    covstrat::DeterminTrainCondStrat, Ktrain::SubsetOfRegsPDMat)
    SoR = SubsetOfRegsStrategy(covstrat)
    μ_SoR, Σ_SoR = predictMVN(xpred, xtrain, ytrain, kernel, meanf, alpha, SoR, Ktrain)
    inducing = covstrat.inducing
    Kuu = Ktrain.Kuu
    
    Kux = cov(kernel, inducing, xpred) # Note: we've already computed this, but this way it looks cleaner
    Qxx = PDMats.Xt_invA_X(Kuu, Kux)
    Σxx = cov(kernel, xpred, xpred)
    
    Σ_DTC = Σxx - Qxx + Σ_SoR
    LinearAlgebra.copytri!(Σ_DTC, 'U')
    return μ_SoR, Σ_DTC
end

function DTC(x::AbstractMatrix, inducing::AbstractMatrix, y::AbstractVector, mean::Mean, kernel::Kernel, logNoise::Real)
    nobs = length(y)
    covstrat = DeterminTrainCondStrat(inducing)
    cK = alloc_cK(covstrat, nobs)
    GPE(x, y, mean, kernel, logNoise, covstrat, EmptyData(), cK)
end

