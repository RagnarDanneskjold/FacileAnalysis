#' Save and load FacileAnalysisResult objects to/from disk.
#'
#' @description
#' \Sexpr[results=rd, stage=render]{lifecycle::badge("experimental")}
#'
#' Saving and loading FacileAnalysisResults can be tricky because they rely
#' on a chain of parent objects that created them, all of which have a reference
#' to the FacileDataStore that they came from.
#'
#' Currenly, the FacileDataStore is removed from every internal object when
#' before it is serialized via `fsave()`. The FacileDataStore is then restored
#' to "just where it needs to be" (using strong assumptions of where it needs
#' to be, instead of logging where it was removed from in `fsave()`) when
#' brought back to life via `fload()`.
#'
#' @details
#' An `fsave_info` attribute will be attached to the serialized object before
#' saving which will be a list that holds information required to materialize
#' the analysis result successfully. Minimally this will include info about how
#' to reconstitute and attach the FacileDataStore that the object was generated
#' from.
#'
#' Elements of `fsave_info` list so far include:
#'
#' - `fds_class`: A string indicating the class of the FacileDataStore that the
#'    result `x` was generated from.
#' - `fds_path`: The path on the filesystem that teh FacileDataStore can be
#'   found. Currently we expect this to be a FacileDataSet
#' - `fds_anno_dir`: The annotation directory for the FacileDataSet
#' - `fds_add`: A descriptor that indicate which elements in the serialized
#'   object should have the fds attached to them, besides itself.
#'
#' @export
#' @rdname serialize
#'
#' @param A `FacileAnalysisResult` object.
#' @param file A path to a file (should support `base::connections` in the
#'   future.
#' @param with_fds Serialize the FacileDataStore with the object? Default is
#'   `FALSE` and you should have a good reason to change this behavior.
#' @return `NULL` for `fsave`, the (correctly sublcassed) `FacileAnalysisResult`
#'   for `fload`, along with `FacileDataStore` (`fds`) attached
fsave <- function(x, file, with_fds = FALSE, ...) {
  UseMethod("fsave", x)
}

#' @noRd
#' @export
fsave.FacileAnalysisResult <- function(x, file, with_fds = FALSE, ...) {
  fds. <- assert_class(fds(x), "FacileDataStore")
  assert_string(file, pattern = "\\.rds$")

  fds.info <- list(fds_class = class(fds.))
  if ("FacileDataSet" %in% fds.info[["fds_class"]]) {
    fds.info[["fds_path"]] <- fds.[["parent.dir"]]
    fds.info[["fds_anno_dir"]] <- fds.[["anno.dir"]]
  }

  x <- unfds(x)
  attr(x, "fsave_info") <- fds.info
  saveRDS(x, file)
}


#' @rdname serialize
#' @export
#' @param fds The `FacileDataStore` the object was run on.
fload <- function(file, fds = NULL, with_fds = TRUE, ...) {
  res <- readRDS(file)
  assert_class(res, "FacileAnalysisResult")

  fds.info <- attr(res, "fsave_info")
  if (is.null(fds.info)) {
    stop("Meta information about connected FacileDataStore not found, ",
         "did you save this object using the FacileAnalysis::fsave() function?")
  }
  assert_list(fds.info, names = "unique")
  assert_subset(c("fds_class"), names(fds.info))
  fds.class <- assert_character(fds.info[["fds_class"]], min.len = 1L)

  if (with_fds) {
    if (is.null(fds) || test_string(fds)) {
      # Implicit FacileDataStores only work with FacileDataSet for now, since
      # it needs to exist in a serialized form on the filesystem anyway, so
      # there is somewhere we can retrieve it from
      if (!"FacileDataSet" %in% fds.class) {
        stop("FacileDataSet required if `fds` not provided")
      }
      if (is.null(fds)) {
        fds <- fds.info[["fds_path"]]
      }
      if (!test_directory_exists(fds, "r")) {
        stop("No path to linked FacileDataStore object found in `file`,
           please pass in a value for `fds` explicitly")
      }
      fds <- FacileData::FacileDataSet(
        fds, anno.dir = fds.info[["fds_anno_dir"]])
    }
    if (!is(fds, "FacileDataStore")) {
      stop("We expected a FacileDataStore by now")
    }
    common.class <- intersect(fds.info[["fds_class"]], class(fds))
    if (length(common.class) == 0L) {
      stop("It doesn't look like the FacileDataStore you are trying to ",
           "associate with this result is the one that was used")
    }
    res <- refds(res, fds)
  }

  res
}
