#' Support harness to initialize and launch a shiny gadget over a facile object.
#'
#' This function handles much of the book keeping code required to setup a shiny
#' gadget around a facile object `x`. There are two
#'
#' This allows us to (shiny)-interact over objects (`x`) that have been created
#' programmaticaly during an analysis, and return relevant interactive events
#' over `x`, or derivative analysis results back to the workspace.
#'
#' @section Flavors of x:
#' We want to support building interactive components over different types of
#' facile objects (`x`). When `x` is a:
#'
#' * `FacileDataStore` the analysis module will include a
#'   [FacileShine::filteredReactiveFacileDataStoreUI()], which allows the user
#'   to interactrively subset down to the samples that the analysis module will
#'   have access to and analyze. The user can then configure and run and
#'   analysis, and subsequently interact with the results.
#'
#' * `facile_sample_frame` the analysis module will be initialized to work over
#'   the samples defined in the facile_frame. The user will then configure the
#'   anlaysis to run from there and be able to interact with the results.
#'
#' * `FacileAnalysisResult` will launch the view over the analysis result,
#'   allowing the user to interact with and explore the result.
#'
#' @importFrom miniUI
#'   gadgetTitleBar
#'   miniContentPanel
#'   miniPage
#' @importFrom multiGSEA failWith
#' @importFrom FacileShine
#'   filteredReactiveFacileDataStore
#'   filteredReactiveFacileDataStoreUI
#'   ReactiveFacileDataStore
#' @importFrom shiny
#'   browserViewer
#'   callModule
#'   dialogViewer
#'   runGadget
#'   tagList
#'   tags
#' @importFrom shinyjs useShinyjs
#' @importFrom shinyWidgets useSweetAlert
#' @param analysisModule the server function for the gadget
#' @param analysisUI the UI function for the gadget
#' @param x the FacileDataStore or a facile sample descriptor from one.
#' @param user the username/id for the analysis
#' @param title the title of the gadget
#' @param height,width height and width of gadget, defaults to 600 and 1000,
#'   respectively.
#' @param viewer `"dialog"` (default), `"browser"`, or `"pane"`. See description
#'   from [shiny::runGadget]
#' @return a subclass of `FacileAnalysisGadgetResult` which holds the result
#'   from the `analysisModule`, as well as am `annotation` tibble, that can hold
#'   information from brushing of smaples (or features) -- depending on what
#'   the gadget is working over.
frunGadget <- function(analysisModule, analysisUI, x, user = Sys.getenv("USER"),
                       title = "Facile Analysis Gadget",
                       height = 800, width = 1000, viewer = "dialog", ...,
                       with_sample_filter = is(x, "FacileDataStore"),
                       retval = "x",
                       debug = FALSE) {
  bs4dash <- getOption("facile.bs4dash")
  options(facile.bs4dash = FALSE)
  on.exit(options(facile.bs4dash = bs4dash))

  assert_function(analysisModule)
  assert_function(analysisUI)

  viewer <- gadget_viewer(viewer, title, width, height)
  restrict_samples <- NULL

  if (is(x, "facile_frame")) {
    fds. <- fds(x)
    samples. <- x
    sample.filter <- FALSE
    restrict_samples <- samples.
  } else if (is(x, "FacileDataStore")) {
    sample.filter <- TRUE
    fds. <- x
    samples. <- collect(samples(x), n = Inf)
  } else if (is(x, "FacileAnalysisResult")) {
    # ugh, this isn't going to work -- I'm writing this in to fire up a
    # ffseaGadget, whose needs to be a FacileAnalysisResult.
    sample.filter <- FALSE
    fds. <- fds(x)
    samples. <- collect(samples(x), n = Inf)
    restrict_samples <- samples.
  } else {
    stop("What in the world?")
  }

  sample.filter <- sample.filter || with_sample_filter
  xtra_covariates <- setdiff(colnames(samples.), c("dataset", "sample_id"))
  if (length(xtra_covariates)) {
    xtra_covariates <- as.EAVtable(samples.)
  } else {
    xtra_covariates <- NULL
  }

  assert_class(fds., "FacileDataStore")
  assert_class(samples., "facile_frame")

  ui.content <- analysisUI("analysis", ..., debug = debug)
  if (sample.filter) {
    ui.content <- tagList(
      filteredReactiveFacileDataStoreUI("ds"),
      tags$hr(),
      ui.content)
  }

  ui <- miniPage(
    useShinyjs(),
    useSweetAlert(),
    if (interactive()) gadgetTitleBar(title) else NULL,
    miniContentPanel(ui.content),
    NULL)

  server <- function(input, output, session) {
    rfds <- ReactiveFacileDataStore(fds., "ds", user = user, samples = samples.)
    analysis <- callModule(analysisModule, "analysis", rfds, ..., debug = debug)

    if (!is.null(xtra_covariates)) {
      observe({
        req(initialized(rfds))
        rfds$.state$esample_annotation <- xtra_covariates
        FacileShine::trigger(rfds, "covariates")
      })
    }

    observeEvent(input$done, {
      annotation <- list(
        samples = FacileShine:::.empty_sample_annotation_tbl(),
        features = FacileShine:::.empty_feature_annotation_tbl())

      if (is(x, "FacileAnalysisResult") && retval != "faro")   {
        if (retval == "x") {
          result. <- x
        } else {
          result. <- analysis[[retval]]
          if (is(result., "reactive")) result. <- result.()
        }
      } else {
        if (is(analysis, "ReactiveFacileAnalysisResultContainer")) {
          result. <- failWith(list(), unreact(faro(analysis)))
          attr(result., "INTERACTED") <- list(
            annotation = annotation)
          class(result.) <- classify_as_gadget(result.)
        } else if (is(analysis, "ReactiveFacileMultiAnalysisResultContainer")) {
          # like the fDgeGseaModule
          results. <- analysis$main
          assert_list(results., names = "unique")
          result. <- lapply(results., function(res) {
            assert_class(res, "ReactiveFacileAnalysisResult")
            unreact(faro(res))
          })
          class(result.) <- "FacileMultiAnalysisResult"
        } else {
          stop("Unexpected `analysis` return type: ", class(analysis)[1L])
        }
      }

      stopApp(invisible(result.))
    })

    observeEvent(input$cancel, {
      stopApp(invisible(NULL))
    })
  }

  if (interactive()) {
    runGadget(ui, server, viewer = viewer, stopOnCancel = FALSE)
  } else {
    # Running in an Rmd with runtime: shiny?
    opts <- list(height = height)
    shiny::shinyApp(ui = ui, server = server, options = opts)
  }
}

#' Extracts interactions over an object that happened in a gadget
#'
#' These are stored and returned as a named list
#'
#' @export
#' @param x any object
#' @return a named list of interactions recorded from running [frunGadget()]
interacted <- function(x, ...) {
  out <- attr(x, "INTERACTED", exact = TRUE)
  if (is.null(out)) {
    warning("No metadata from gadget interaction found in x")
    out <- list()
  }
  out
}

#' @export
#' @importFrom FacileShine annotation
#' @noRd
annotation.FacileAnalysisGadgetResult <- function(x, type = NULL, ...) {
  annos <- interacted(x)[["annotation"]]
  if (is.list(annos) && !is.null(type)) {
    assert_choice(type, names(annos))
    annos <- annos[[type]]
  }
  annos
}


#' @noRd
#' @importFrom shiny browserViewer dialogViewer paneViewer
gadget_viewer <- function(type = c("dialog", "browser", "pane"),
                          title = "Facile Gadget",
                          width = 800, height = 600, minHeight = height,
                          ...) {
  type <- match.arg(type)
  switch(type,
         dialog = dialogViewer(title, width, height),
         browser = browserViewer(),
         pane = paneViewer(minHeight = minHeight))
}
