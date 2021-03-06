% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/assay_dynamics.R
\name{step_assay_dynamics}
\alias{step_assay_dynamics}
\title{Step Assay Dynamics}
\usage{
step_assay_dynamics(x, diagnostic_delay)
}
\arguments{
\item{x}{The time since infection}

\item{diagnostic_delay}{The number of days since infection after which time all the results will be positive.}
}
\description{
Returns the probability of testing positive x days after infection
}
\details{
The simplest scheme is used to compute these probabilities. Each assay is characterized by a diagnostic delay after which time all of the results will be positive. Before this time, all results will be negative.
}
