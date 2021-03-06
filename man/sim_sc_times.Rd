% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sims.R
\name{sim_sc_times}
\alias{sim_sc_times}
\title{Simulate time to seroconversion}
\usage{
sim_sc_times(list_of_assays, skip_order_check = TRUE, fix_draw = NULL)
}
\arguments{
\item{list_of_assays}{ORDERED list of assays for which test results should be produced. They must be ordered with the fastest assay first (fastest = assay with the shortest window period)}

\item{skip_order_check}{When set to TRUE (the default), it is assumed that the order of the list_of_assays is correct. It is EXTREMELY important that this order is correct. This option defaults to TRUE since this step is very slow, so run it the first time only to check that your list is ordered correctly (by setting skip_order_check = FALSE).}

\item{fix_draw}{Provides the option to fix the draws so that it is no longer random. Useful for constructing examples and systematic evaluations.}
}
\description{
Given a list of assays (ordered according to window period - from short to long) assume that the infecting exposure occurred at time zero and simulate at what time each assay will start to produce positive results. This output can then be combined with a visit schedule to simulate test results for a diagnostic history.
}
