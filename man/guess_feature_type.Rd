% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/feature-types.R
\name{guess_feature_type}
\alias{guess_feature_type}
\title{Guesses the type of identifiers provided.}
\usage{
guess_feature_type(x, with_organism = TRUE, summarize = TRUE)
}
\arguments{
\item{x}{a character vector of ids}
}
\value{
data.frame with \code{id} (\code{x}) and \code{id_type}. If \code{with_organism = TRUE},
a third \code{organism} column is added with a guess for the organism.
}
\description{
A two-column data.frame is returned for id_type and organism. Organism
is "unknown" for identifiers where there this can't be inferred (like Refseq).

If an identifier matches more than one id_type, the id_type is set to
\code{"ambiguous"}. If the identifier doesn't match any guesses, then \code{"unknown"}.
}
\details{
This was extracted from the \code{guess_id_type} in the DenaliSigDb package.
We are using it as temporary bandaid to extract the "feature space" from
results. These should be straightforward to extract when all analyses are
going through some type of FacileDataStore.
}
