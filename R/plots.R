# Part of the rstap package for estimating model parameters
# Copyright (C) 2015, 2016, 2017 Trustees of Columbia University
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

#' Plot method for stapreg objects
#'
#' The \code{plot} method for \link{stapreg-objects} provides a convenient 
#' interface to the \link[bayesplot]{MCMC} module in the \pkg{\link{bayesplot}} 
#' package for plotting MCMC draws and diagnostics. It is also straightforward 
#' to use the functions from the \pkg{bayesplot} package directly rather than 
#' via the \code{plot} method. Examples of both methods of plotting are given
#' below.
#'
#' @method plot stapreg
#' @export
#' @templateVar stapregArg x
#' @template args-stapreg-object
#' @template args-pars
#' @template args-regex-pars
#' @param plotfun A character string naming the \pkg{bayesplot} 
#'   \link[bayesplot]{MCMC} function to use. The default is to call
#'   \code{\link[bayesplot]{mcmc_intervals}}. \code{plotfun} can be specified
#'   either as the full name of a \pkg{bayesplot} plotting function (e.g.
#'   \code{"mcmc_hist"}) or can be abbreviated to the part of the name following
#'   the \code{"mcmc_"} prefix (e.g. \code{"hist"}). To get the names of all
#'   available MCMC functions see \code{\link[bayesplot]{available_mcmc}}.
#'
#' @param ... Additional arguments to pass to \code{plotfun} for customizing the
#'   plot. These are described on the help pages for the individual plotting 
#'   functions. For example, the arguments accepted for the default
#'   \code{plotfun="intervals"} can be found at
#'   \code{\link[bayesplot]{mcmc_intervals}}.
#'
#' @return Either a ggplot object that can be further customized using the
#'   \pkg{ggplot2} package, or an object created from multiple ggplot objects
#'   (e.g. a gtable object created by \code{\link[gridExtra]{arrangeGrob}}).
#'
#' @seealso
#' \itemize{ 
#'   \item The vignettes in the \pkg{bayesplot} package for many examples.
#'   \item \code{\link[bayesplot]{MCMC-overview}} (\pkg{bayesplot}) for links to
#'   the documentation for all the available plotting functions.
#'   \item \code{\link[bayesplot]{color_scheme_set}} (\pkg{bayesplot}) to change
#'   the color scheme used for plotting.
#'   \item \code{\link{pp_check}} for graphical posterior predictive checks.
#' }  
#'
#' @template reference-bayesvis
#' @importFrom ggplot2 ggplot aes_string xlab %+replace% theme
#'
#'@examples
#'\dontrun{
#' # Not run for CRAN check speed
#' fit_glm <- stap_glm(formula = y ~ sex + sap(Fast_Food),
#'                    subject_data = homog_subject_data,
#'                      distance_data = homog_distance_data,
#'                      family = gaussian(link = 'identity'),
#'                      subject_ID = 'subj_id',
#'                      prior = normal(location = 0, scale = 5, autoscale = F),
#'                      prior_intercept = normal(location = 25, scale = 5, autoscale = F),
#'                      prior_stap = normal(location = 0, scale = 3, autoscale = F),
#'                      prior_theta = log_normal(location = 1, scale = 1),
#'                      prior_aux = cauchy(location = 0,scale = 5),
#'                      max_distance = max(homog_distance_data$Distance),
#'                      chains = CHAINS, iter = ITER,
#'                      refresh = -1,verbose = F)
#'
#'plot(fit_glm, plotfun = 'mcmc_hist', pars = "Fast_Food")
#'}
#'
plot.stapreg <- function(x, plotfun = "intervals", pars = NULL,
                         regex_pars = NULL, ...) {
  
  if (plotfun %in% c("pairs", "mcmc_pairs"))
    return(pairs.stapreg(x, pars = pars, regex_pars = regex_pars, ...))
  
  fun <- set_plotting_fun(plotfun)
  args <- set_plotting_args(x, pars, regex_pars, ..., plotfun = plotfun)
  do.call(fun, args)
}




# internal for plot.stapreg ----------------------------------------------

# Prepare argument list to pass to plotting function
#
# @param x stapreg object
# @param pars, regex_pars user specified pars and regex_pars arguments (can be
#   missing)
# @param ...  additional arguments to pass to the plotting function
# @param plotfun User's 'plotfun' argument
set_plotting_args <- function(x, pars = NULL, regex_pars = NULL, ...,
                              plotfun = character()) {

  plotfun <- mcmc_function_name(plotfun)

  .plotfun_is_type <- function(patt) {
    grepl(pattern = paste0("_", patt), x = plotfun, fixed = TRUE)
  }
  
  if (.plotfun_is_type("nuts")) {
    nuts_stuff <- list(x = bayesplot::nuts_params(x), ...)
    if (!.plotfun_is_type("energy"))
      nuts_stuff[["lp"]] <- bayesplot::log_posterior(x)
    return(nuts_stuff)
  }
  if (.plotfun_is_type("rhat")) {
    rhat <- bayesplot::rhat(x, pars = pars, regex_pars = regex_pars)
    return(list(rhat = rhat, ...))
  }
  if (.plotfun_is_type("neff")) {
    ratio <- bayesplot::neff_ratio(x, pars = pars, regex_pars = regex_pars)
    return(list(ratio = ratio, ...))
  }
  if (!is.null(pars) || !is.null(regex_pars)) {
    pars <- collect_pars(x, pars, regex_pars)
    pars <- allow_special_parnames(x, pars)
  }
  
  
  if (needs_chains(plotfun))
    list(x = as.array(x, pars = pars, regex_pars = regex_pars), ...)
  else
    list(x = as.matrix(x, pars = pars, regex_pars = regex_pars), ...)
}

mcmc_function_name <- function(fun) {
  # to keep backwards compatibility convert old function names
  if (fun == "scat") {
    fun <- "scatter"
  } else if (fun == "ess") {
    fun <- "neff"
  } else if (fun == "ac") {
    fun <- "acf"
  } else if (fun %in% c("diag", "stan_diag")) {
    stop(
      "For NUTS diagnostics, instead of 'stan_diag', ",
      "please specify the name of one of the functions listed at ",
      "help('NUTS', 'bayesplot')",
      call. = FALSE
    )
  }

  if (identical(substr(fun, 1, 4), "ppc_"))
    stop(
      "For 'ppc_' functions use the 'pp_check' ",
      "method instead of 'plot'.",
      call. = FALSE
    )

  if (!identical(substr(fun, 1, 5), "mcmc_"))
    fun <- paste0("mcmc_", fun)
  
  if (!fun %in% bayesplot::available_mcmc())
    stop(
      fun, " is not a valid MCMC function name.",  
      " Use bayesplot::available_mcmc() for a list of available MCMC functions."
    )

  return(fun)
}

# check if a plotting function requires multiple chains
needs_chains <- function(x) {
  nms <- paste0("mcmc_",
    c(
      "trace",
      "trace_highlight",
      "acf",
      "acf_bar",
      "hist_by_chain",
      "dens_overlay",
      "violin",
      "combo"
    )
  )
  mcmc_function_name(x) %in% nms
}

# Select the correct plotting function
# @param plotfun user specified plotfun argument (can be missing)
set_plotting_fun <- function(plotfun = NULL) {
  if (is.null(plotfun))
    return("mcmc_intervals")
  if (!is.character(plotfun))
    stop("'plotfun' should be a string.", call. = FALSE)

  plotfun <- mcmc_function_name(plotfun)
  fun <- try(get(plotfun, pos = asNamespace("bayesplot"), mode = "function"), 
             silent = TRUE)
  if (!inherits(fun, "try-error"))
    return(fun)
  
  stop(
    "Plotting function ",  plotfun, " not found. ",
    "A valid plotting function is any function from the ",
    "'bayesplot' package beginning with the prefix 'mcmc_'.",
    call. = FALSE
  )
}



# pairs method ------------------------------------------------------------
#' Pairs method for stapreg objects
#' 
#' Interface to \pkg{bayesplot}'s \code{\link[bayesplot]{mcmc_pairs}} function 
#' for use with \pkg{rstap} models. Be careful not to specify too
#' many parameters to include or the plot will be both hard to read and slow to
#' render.
#'
#' @method pairs stapreg
#' @export
#' @importFrom bayesplot pairs_style_np pairs_condition
#' @export pairs_style_np pairs_condition
#' @aliases pairs_style_np pairs_condition
#' 
#' @templateVar stapregArg x
#' @template args-stapreg-object
#' @template args-regex-pars
#' @param pars An optional character vetor of parameter names. All parameters 
#'   are included by default, but for models with more than just a few 
#'   parameters it may be far too many to visualize on a small computer screen 
#'   and also may require substantial computing time.
#' @param condition Same as the \code{condition} argument to 
#'   \code{\link[bayesplot]{mcmc_pairs}} except the \emph{default is different}
#'   for \pkg{rstap} models. By default, the \code{mcmc_pairs} function in
#'   the \pkg{bayesplot} package plots some of the Markov chains (half, in the
#'   case of an even number of chains) in the panels above the diagonal and the
#'   other half in the panels below the diagonal. However since we know that 
#'   \pkg{rstap} models were fit using Stan (which \pkg{bayesplot} doesn't 
#'   assume) we can make the default more useful by splitting the draws 
#'   according to the \code{accept_stat__} diagnostic. The plots below the 
#'   diagonal will contain realizations that are below the median 
#'   \code{accept_stat__} and the plots above the diagonal will contain 
#'   realizations that are above the median \code{accept_stat__}. To change this
#'   behavior see the documentation of the \code{condition} argument at 
#'   \code{\link[bayesplot]{mcmc_pairs}}.
#' @param ... Optional arguments passed to \code{\link[bayesplot]{mcmc_pairs}}. 
#'   The \code{np}, \code{lp}, and \code{max_treedepth} arguments to 
#'   \code{mcmc_pairs} are handled automatically by \pkg{rstap} and do not 
#'   need to be specified by the user in \code{...}. The arguments that can be 
#'   specified in \code{...} include \code{transformations}, \code{diag_fun},
#'   \code{off_diag_fun}, \code{diag_args}, \code{off_diag_args},
#'   and \code{np_style}. These arguments are
#'   documented thoroughly on the help page for
#'   \code{\link[bayesplot]{mcmc_pairs}}.
#'
pairs.stapreg <-
  function(x,
           pars = NULL,
           regex_pars = NULL,
           condition = pairs_condition(nuts = "accept_stat__"),
           ...) {
    
    dots <- list(...)
    ignored_args <- c("np", "lp", "max_treedepth")
    specified <- ignored_args %in% names(dots)
    if (any(specified)) {
      warning(
        "The following arguments were ignored because they are ",
        "specified automatically by rstap: ", 
        paste(sQuote(ignored_args[specified]), collapse = ", ")
      )
    }
    
    posterior <- as.array.stapreg(x, pars = pars, regex_pars = regex_pars)
    if (is.null(pars) && is.null(regex_pars)) {
      # include log-posterior by default
      lp_arr <- as.array.stapreg(x, pars = "log-posterior")
      dd <- dim(posterior)
      dn <- dimnames(posterior)
      dd[3] <- dd[3] + 1
      dn$parameters <- c(dn$parameters, "log-posterior")
      tmp <- array(NA, dim = dd, dimnames = dn)
      tmp[,, 1:(dd[3] - 1)] <- posterior
      tmp[,, dd[3]] <- lp_arr
      posterior <- tmp
    }
    posterior <- round(posterior, digits = 12)
    
    bayesplot::mcmc_pairs(
      x = posterior, 
      np = bayesplot::nuts_params(x$stapfit),  
      lp = bayesplot::log_posterior(x$stapfit),  
      max_treedepth = .max_treedepth(x$stapfit),
      condition = condition,
      ...
    )
    
  }

# internal for pairs.stapreg ----------------------------------------------

# @param x stapreg object
.max_treedepth <- function(x) {
  control <- x@stan_args[[1]]$control
  if (is.null(control)) {
    max_td <- 10
  } else {
    max_td <- control$max_treedepth
    if (is.null(max_td))
      max_td <- 10
  }
  return(max_td)
}
