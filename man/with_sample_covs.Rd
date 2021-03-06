% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/facile_api_extras.R
\name{with_sample_covs}
\alias{with_sample_covs}
\title{Retrieves sample covariates with option to use custom covariates by user.}
\usage{
with_sample_covs(
  x,
  covariates = NULL,
  custom_covariates = NULL,
  custom_key = Sys.getenv("USER"),
  ...,
  verbose = FALSE
)
}
\arguments{
\item{x}{a sample descriptor (facile_frame)}

\item{covariates}{the names of the covariates to retrieve from the datstore.
Defaults to \code{NULL}, which is all of them.}

\item{custom_covariates}{a wide (sample, dataset, cov1, cov2, ...) data.frame
of extra covariates the user wants to add to the sampel descriptor \code{x}.}

\item{custom_key}{for \code{\link[FacileData:sample-covariates]{FacileData::with_sample_covariates()}}}
}
\value{
a wider version of \code{x} with more covariates attached to it.
}
\description{
This returns a mix of custom covs that might be provided by a passed (wide)
data.frame and the ones stored in the datastore. Covariates passed in by an
extra data.frame or the original sample descriptor are given higher
precedence.
}
