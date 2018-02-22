#' Create a new layer
#'
#' A layer is a combination of data, stat and geom with a potential position
#' adjustment. Usually layers are created using `geom_*` or `stat_*`
#' calls but it can also be created directly using this function.
#'
#' @export
#' @inheritParams geom_point
#' @param mapping Set of aesthetic mappings created by [aes()] or
#'   [aes_()]. If specified and `inherit.aes = TRUE` (the
#'   default), it is combined with the default mapping at the top level of the
#'   plot. You must supply `mapping` if there is no plot mapping.
#' @param data The data to be displayed in this layer. There are three
#'    options:
#'
#'    If `NULL`, the default, the data is inherited from the plot
#'    data as specified in the call to [ggplot()].
#'
#'    A `data.frame`, or other object, will override the plot
#'    data. All objects will be fortified to produce a data frame. See
#'    [fortify()] for which variables will be created.
#'
#'    A `function` will be called with a single argument,
#'    the plot data. The return value must be a `data.frame.`, and
#'    will be used as the layer data.
#' @param geom The geometric object to use display the data
#' @param stat The statistical transformation to use on the data for this
#'    layer, as a string.
#' @param position Position adjustment, either as a string, or the result of
#'  a call to a position adjustment function.
#' @param show.legend logical. Should this layer be included in the legends?
#'   `NA`, the default, includes if any aesthetics are mapped.
#'   `FALSE` never includes, and `TRUE` always includes.
#'   It can also be a named logical vector to finely select the aesthetics to
#'   display.
#' @param inherit.aes If `FALSE`, overrides the default aesthetics,
#'   rather than combining with them. This is most useful for helper functions
#'   that define both data and aesthetics and shouldn't inherit behaviour from
#'   the default plot specification, e.g. [borders()].
#' @param check.aes,check.param If `TRUE`, the default, will check that
#'   supplied parameters and aesthetics are understood by the `geom` or
#'   `stat`. Use `FALSE` to suppress the checks.
#' @param params Additional parameters to the `geom` and `stat`.
#' @param subset DEPRECATED. An older way of subsetting the dataset used in a
#'   layer.
#' @keywords internal
#' @examples
#' # geom calls are just a short cut for layer
#' ggplot(mpg, aes(displ, hwy)) + geom_point()
#' # shortcut for
#' ggplot(mpg, aes(displ, hwy)) +
#'   layer(geom = "point", stat = "identity", position = "identity",
#'     params = list(na.rm = FALSE)
#'   )
#'
#' # use a function as data to plot a subset of global data
#' ggplot(mpg, aes(displ, hwy)) +
#'   layer(geom = "point", stat = "identity", position = "identity",
#'     data = head, params = list(na.rm = FALSE)
#'   )
#'
layer <- function(geom = NULL, stat = NULL,
                  data = NULL, mapping = NULL,
                  position = NULL, params = list(),
                  inherit.aes = TRUE, check.aes = TRUE, check.param = TRUE,
                  subset = NULL, show.legend = NA) {
  if (is.null(geom))
    stop("Attempted to create layer with no geom.", call. = FALSE)
  if (is.null(stat))
    stop("Attempted to create layer with no stat.", call. = FALSE)
  if (is.null(position))
    stop("Attempted to create layer with no position.", call. = FALSE)

  # Handle show_guide/show.legend
  if (!is.null(params$show_guide)) {
    warning("`show_guide` has been deprecated. Please use `show.legend` instead.",
      call. = FALSE)
    show.legend <- params$show_guide
    params$show_guide <- NULL
  }
  if (!is.logical(show.legend)) {
    warning("`show.legend` must be a logical vector.", call. = FALSE)
    show.legend <- FALSE
  }

  data <- fortify(data)

  if (!is.null(mapping)) {
    mapping <- validate_mapping(mapping)
  }

  if (is.character(geom))
    geom <- find_subclass("Geom", geom, parent.frame())
  if (is.character(stat))
    stat <- find_subclass("Stat", stat, parent.frame())
  if (is.character(position))
    position <- find_subclass("Position", position, parent.frame())

  # Special case for na.rm parameter needed by all layers
  if (is.null(params$na.rm)) {
    params$na.rm <- FALSE
  }

  # Split up params between aesthetics, geom, and stat
  params <- rename_aes(params)
  aes_params  <- params[intersect(names(params), geom$aesthetics())]
  geom_params <- params[intersect(names(params), geom$parameters(TRUE))]
  stat_params <- params[intersect(names(params), stat$parameters(TRUE))]

  all <- c(geom$parameters(TRUE), stat$parameters(TRUE), geom$aesthetics())

  # Warn about extra params and aesthetics
  extra_param <- setdiff(names(params), all)
  if (check.param && length(extra_param) > 0) {
    warning(
      "Ignoring unknown parameters: ", paste(extra_param, collapse = ", "),
      call. = FALSE,
      immediate. = TRUE
    )
  }

  extra_aes <- setdiff(
    mapped_aesthetics(mapping),
    c(geom$aesthetics(), stat$aesthetics())
  )
  if (check.aes && length(extra_aes) > 0) {
    warning(
      "Ignoring unknown aesthetics: ", paste(extra_aes, collapse = ", "),
      call. = FALSE,
      immediate. = TRUE
    )
  }


  subset <- rlang::enquo(subset)

  ggproto("LayerInstance", Layer,
    geom = geom,
    geom_params = geom_params,
    stat = stat,
    stat_params = stat_params,
    data = data,
    mapping = mapping,
    aes_params = aes_params,
    subset = subset,
    position = position,
    inherit.aes = inherit.aes,
    show.legend = show.legend
  )
}

validate_mapping <- function(mapping) {
  if (!inherits(mapping, "uneval")) {
    msg <- paste0("`mapping` must be created by `aes()`")
    if (inherits(mapping, "ggplot")) {
      msg <- paste0(
        msg, "\n",
        "Did you use %>% instead of +?"
      )
    }

    stop(msg, call. = FALSE)
  }

  # For backward compatibility with pre-tidy-eval layers
  new_aes(lapply(mapping, ensure_quosure))
}

Layer <- ggproto("Layer", NULL,
  geom = NULL,
  geom_params = NULL,
  stat = NULL,
  stat_params = NULL,
  data = NULL,
  aes_params = NULL,
  mapping = NULL,
  position = NULL,
  inherit.aes = FALSE,

  print = function(self) {
    if (!is.null(self$mapping)) {
      cat("mapping:", clist(self$mapping), "\n")
    }
    cat(snakeize(class(self$geom)[[1]]), ": ", clist(self$geom_params), "\n",
      sep = "")
    cat(snakeize(class(self$stat)[[1]]), ": ", clist(self$stat_params), "\n",
      sep = "")
    cat(snakeize(class(self$position)[[1]]), "\n")
  },

  layer_data = function(self, plot_data) {
    if (is.waive(self$data)) {
      plot_data
    } else if (is.function(self$data)) {
      data <- self$data(plot_data)
      if (!is.data.frame(data)) {
        stop("Data function must return a data.frame", call. = FALSE)
      }
      data
    } else {
      self$data
    }
  },

  compute_aesthetics = function(self, data, plot) {
    # For annotation geoms, it is useful to be able to ignore the default aes
    if (self$inherit.aes) {
      aesthetics <- defaults(self$mapping, plot$mapping)
    } else {
      aesthetics <- self$mapping
    }

    # Drop aesthetics that are set or calculated
    set <- names(aesthetics) %in% names(self$aes_params)
    calculated <- is_calculated_aes(aesthetics)
    aesthetics <- aesthetics[!set & !calculated]

    # Override grouping if set in layer
    if (!is.null(self$geom_params$group)) {
      aesthetics[["group"]] <- self$aes_params$group
    }

    # Old subsetting method
    if (!rlang::quo_is_null(self$subset)) {
      res <- rlang::eval_tidy(self$subset, data = data)
      res <- res & !is.na(res)
      data <- data[res, , drop = FALSE]
    }

    scales_add_defaults(plot$scales, data, aesthetics)

    # Evaluate and check aesthetics
    aesthetics <- compact(aesthetics)
    evaled <- lapply(aesthetics, rlang::eval_tidy, data = data)

    n <- nrow(data)
    if (n == 0) {
      # No data, so look at longest evaluated aesthetic
      if (length(evaled) == 0) {
        n <- 0
      } else {
        n <- max(vapply(evaled, length, integer(1)))
      }
    }
    check_aesthetics(evaled, n)

    # Set special group and panel vars
    if (empty(data) && n > 0) {
      evaled$PANEL <- 1
    } else {
      evaled$PANEL <- data$PANEL
    }
    evaled <- lapply(evaled, unname)
    evaled <- as.data.frame(tibble::as_tibble(evaled))
    evaled <- add_group(evaled)
    evaled
  },

  compute_statistic = function(self, data, layout) {
    if (empty(data))
      return(data.frame())

    params <- self$stat$setup_params(data, self$stat_params)
    data <- self$stat$setup_data(data, params)
    self$stat$compute_layer(data, params, layout)
  },

  map_statistic = function(self, data, plot) {
    if (empty(data)) return(data.frame())

    # Assemble aesthetics from layer, plot and stat mappings
    aesthetics <- self$mapping
    if (self$inherit.aes) {
      aesthetics <- defaults(aesthetics, plot$mapping)
    }
    aesthetics <- defaults(aesthetics, self$stat$default_aes)
    aesthetics <- compact(aesthetics)

    new <- strip_dots(aesthetics[is_calculated_aes(aesthetics)])
    if (length(new) == 0) return(data)

    # Add map stat output to aesthetics
    env <- new.env(parent = baseenv())
    env$calc <- calc

    stat_data <- plyr::quickdf(lapply(new, rlang::eval_tidy, data, env))
    names(stat_data) <- names(new)

    # Add any new scales, if needed
    scales_add_defaults(plot$scales, data, new)
    # Transform the values, if the scale say it's ok
    # (see stat_spoke for one exception)
    if (self$stat$retransform) {
      stat_data <- scales_transform_df(plot$scales, stat_data)
    }

    cunion(stat_data, data)
  },

  compute_geom_1 = function(self, data) {
    if (empty(data)) return(data.frame())
    data <- self$geom$setup_data(data, c(self$geom_params, self$aes_params))

    check_required_aesthetics(
      self$geom$required_aes,
      c(names(data), names(self$aes_params)),
      snake_class(self$geom)
    )

    data
  },

  compute_position = function(self, data, layout) {
    if (empty(data)) return(data.frame())

    params <- self$position$setup_params(data)
    data <- self$position$setup_data(data, params)

    self$position$compute_layer(data, params, layout)
  },

  compute_geom_2 = function(self, data) {
    # Combine aesthetics, defaults, & params
    if (empty(data)) return(data)

    self$geom$use_defaults(data, self$aes_params)
  },

  finish_statistics = function(self, data) {
    self$stat$finish_layer(data, self$stat_params)
  },

  draw_geom = function(self, data, layout) {
    if (empty(data)) {
      n <- nrow(layout$layout)
      return(rep(list(zeroGrob()), n))
    }

    data <- self$geom$handle_na(data, self$geom_params)
    self$geom$draw_layer(data, self$geom_params, layout, layout$coord)
  }
)

is.layer <- function(x) inherits(x, "Layer")


find_subclass <- function(super, class, env) {
  name <- paste0(super, camelize(class, first = TRUE))
  obj <- find_global(name, env = env)

  if (is.null(obj)) {
    stop("No ", tolower(super), " called '", class, "'.", call. = FALSE)
  } else if (!inherits(obj, super)) {
    stop("Found object is not a ", tolower(super), ".", call. = FALSE)
  }

  obj
}
