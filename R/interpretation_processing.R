#' Estimates the 2.5, 50 and 97.5 percentiles and much more
#'
#' Various hacks required to get the numerical integration and optimization working.
#'
#' @param fun The function whose percentiles are required
#' @param range_start Start of interval containing the percentiles
#' @param range_end End of interval containing the percentiles
#' @param verbose Should verbose output be printed?
#' @param label A label to print out with warnings. ptid is a good candidate
#' @param warn_low_AOC Should a warning be issued when AOC is low? default = FALSE
#' @param extra_tiles A vector of additional percentiles to compute. If NULL, this process will be skipped.
#' @param date_splits Compute the AOC to the left of each of the dates listed in this parameter. If NULL, this process will be skipped.
#' @export

estimate_lb_med_ub <- function(fun, range_start, range_end, verbose = FALSE, label = 'unlabeled', 
                               warn_low_AOC = FALSE, extra_tiles = NULL, date_splits = NULL){
  if (FALSE){
    range_start <- -100
    range_end <- 100
    fun <- dexp
    fun <- dnorm

    tiles <- c(0.025, 0.5, 0.975)
    qnorm(tiles)
    qexp(tiles)

    devtools::load_all('/home/phillipl/projects/tsic/code/tsic')
    dat <- load_dsmb_nov_2019_data(file_name = '/fridge/data/AMP/DSMB_timing_nov_2019/AMP_diagnostic_testing_history_DSMB_2019_Nov.csv')
    ihist <- subset(dat, ptid == 'p_703-0203')
    agg_inter <-  construct_aggregate_interpreter(ihist)
    fun <- agg_inter
    range_start <- floor(min(ihist$sample_date) - 60)
    range_end <- ceiling(max(ihist$sample_date) + 30)
    verbose <- TRUE
    label <- unique(ihist$ptid)

    # debugging qexp(0.6)
    verbose = FALSE
    label = 'unlabeled'
    warn_low_AOC = FALSE
    date_splits = NULL
    fun = dexp
    range_start = range_to_int$range_start
    range_end = range_to_int$range_end
    extra_tiles = (1:9)/10
  }
  if (!is.null(date_splits)){
    for (indx in 1:length(date_splits)){
      stopifnot(date_splits[indx] > range_start)
      stopifnot(date_splits[indx] < range_end)
      if (date_splits[indx]%%1 != 0.5){
        warning('Some date split not at midday')
      }
    }
  }
  if (verbose){cat('trim range\n')}
  ranges <- trim_range(fun, range_start, range_end, tol = 0.1^50)
  range_start <- ranges$range_start
  range_end <- ranges$range_end
  if (verbose){cat('get_scatter\n')}
  xy_points <- get_scatterpoints(fun, range_start:range_end, max_delta = 0.001, min_length = 0.001)
  if (verbose){cat('reduce_x\n')}
  xy_points <- reduce_x_points(xy_points$x, xy_points$y)

  if (verbose){cat('pracma::integral\n')}
  range_start <- min(xy_points$x)
  range_end <- max(xy_points$x)
  total_aoc <- pracma::integral(fun = fun,
                                xmin = range_start,
                                xmax = range_end,
                                no_intervals = 1000)
  if (total_aoc < 2 & warn_low_AOC){warning('AOC low')}

  if (verbose){cat('manual rieman integral\n')}
  midpoint_heights <- (xy_points$y[1:(length(xy_points$y)-1)] + xy_points$y[2:(length(xy_points$y))]) / 2
  int_lengths <- xy_points$x[2:(length(xy_points$x))] - xy_points$x[1:(length(xy_points$x)-1)]
  riemans <- midpoint_heights * int_lengths
#  rieman_total_aoc <- sum(riemans)

  if (total_aoc <= 0.0001){
    print(total_aoc)
    return('no solution')
  }  

  integrated_fun <- function(x, no_intervals = 100){
    pracma::integral(fun = function(x){fun(x)/total_aoc},
                     xmin = range_start, 
                     xmax = min(x, range_end),
                     no_intervals = no_intervals)
  }

  midpoints <- (xy_points$x[2:(length(xy_points$x))] + xy_points$x[1:(length(xy_points$x)-1)]) / 2
  probs <- cumsum(riemans)
  probs <- probs / max(probs)
  x <- midpoints
#  plot(probs ~ x)

  find_perc <- function(value, width_toggle){
#  value <- 0.025
#  width_toggle <- 0.01
    start_indx <- max(which(probs < value - width_toggle))
    end_indx <- min(which(probs > value + width_toggle))

    m2_start_indx <- max(which( probs < ((value - width_toggle)/2) ))
    m2_end_indx <- min(which(probs > ((value + width_toggle)/2) ))

    tight_range_start <- x[start_indx]
    tight_range_end <- x[end_indx]
    m2_range_start <- x[m2_start_indx]
    m2_range_end <- x[m2_end_indx]
#    print(c(range_start, range_end, 
#          tight_range_start, tight_range_end, 
#          (tight_range_start + range_start)/2, (tight_range_end + range_end)/2))

    c_perc_w <- optimize(f = function(x){abs(integrated_fun(x) - value)},
                         interval = c(range_start, range_end),
                         tol = 2.220446e-16)
    c_perc_t <- optimize(f = function(x){abs(integrated_fun(x) - value)},
                         interval = c(tight_range_start, tight_range_end),
                         tol = 2.220446e-16)
    c_perc_m <- optimize(f = function(x){abs(integrated_fun(x) - value)},
                         interval = c((tight_range_start + range_start)/2, 
                                      (tight_range_end + range_end)/2),
                         tol = 2.220446e-16)
    c_perc_m2 <- optimize(f = function(x){abs(integrated_fun(x) - value)},
                         interval = c(m2_range_start, m2_range_end),
                         tol = 2.220446e-16)

    if (c_perc_w$objective < c_perc_t$objective){
      c_perc <- c_perc_w
    } else {
      c_perc <- c_perc_t
    }
    if (c_perc_m$objective < c_perc$objective){
      c_perc <- c_perc_m
    }
    if (c_perc_m2$objective < c_perc$objective){
      c_perc <- c_perc_m2
    }

    return(c_perc)
  }

  aoc_left_of_date <- NULL
  if (!is.null(date_splits)){
    for (indx in 1:length(date_splits)){
      aoc_left_of_date <- c(aoc_left_of_date, integrated_fun(date_splits[indx], no_intervals = 1000))
    }
  }

  if (verbose){cat('solving for lb\n')}
  lb  <- find_perc(value = 0.025, width_toggle = 0.01)
  if (verbose){cat('solving for med\n')}
  med <- find_perc(value = 0.500, width_toggle = 0.01)
  if (verbose){cat('solving for ub\n')}
  ub  <- find_perc(value = 0.975, width_toggle = 0.01)
  extra_computed_tiles <- list()
  if (!is.null(extra_tiles)){
    for (i in 1:length(extra_tiles)){
      extra_computed_tiles <- c(extra_computed_tiles, list(find_perc(value = extra_tiles[i], width_toggle = 0.01)))
      names(extra_computed_tiles)[i] <- extra_tiles[i]
    }
  }

  return(list(lb = lb$minimum,
              med = med$minimum,
              ub = ub$minimum,
              aoc = total_aoc,
              extra_tiles = extra_tiles,
              extra_computed_tiles = extra_computed_tiles,
              date_splits = date_splits,
              aoc_left_of_date = aoc_left_of_date,
              max_agg = max(xy_points$y)))
}

#' Computes probability that infection was on each of a range of days
#'
#' Given an aggregate curve, a range of dates and the total area under the curve compute a vector of probabilities so that each element reflects the probability that infection occurred on a specific day.
#'
#' If the amount of mass in the first (last) of the daily intervals exceeds the end_mass_thresh value, then another expansion_size daily blocks will be added to the front (back) of the interval until either the first (last) interval's mass no longer exceeds the end_mass_thresh value, or more than max_days_extend days was added to the interval.
#'
#' @param agg_fun The aggregate curve associated with the ihist of interest as computed by construct_aggregate_interpreter.
#' @param tauc The total area under the aggregate curve.
#' @param range_start The start of the range over which daily probabilities should be computed.
#' @param range_end The end of the range over which daily probabilities should be computed.
#' @export

compute_daily_grid <- function(agg_fun, tauc, range_start, range_end, end_mass_thresh = 1/1e10, 
                               max_days_extend = 100, expansion_size = 20){
  if (FALSE) {
    devtools::load_all('/home/phillipl/projects/tsic/code/tsic')
    dat <- load_dsmb_nov_2019_data(file_name = '/fridge/data/AMP/DSMB_timing_nov_2019/AMP_diagnostic_testing_history_DSMB_2019_Nov.csv')
    unique(dat$ptid)
    ihist <- subset(dat, ptid == 'p_703-0013')
    inf_ihist <- select_most_informative_results(ihist)$kept_ihist
    agg_inter <-  construct_aggregate_interpreter(inf_ihist)
    agg_fun <- agg_inter
    range_start <- floor(min(inf_ihist$sample_date))
    range_start <- floor(min(inf_ihist$sample_date) - 60)
    range_end <- ceiling(max(inf_ihist$sample_date) + 30)
    lb_med_ub <- estimate_lb_med_ub(agg_fun, range_start, range_end)
    tauc <- lb_med_ub$aoc

    end_mass_thresh = 1/1e6 
    max_days_extend = 100
    expansion_size = 20

  }
  daily_integrals <- data.frame(
    interval_start = (range_start):(range_end-1),
    interval_end = (range_start+1):(range_end),
    mass = -1,
    done = 0,
    stringsAsFactors = FALSE
    )

  while (sum(daily_integrals$done) != nrow(daily_integrals)){
    c_indx <- sort(which(daily_integrals$done == 0))[1]
    c_int <- daily_integrals[c_indx, , drop=FALSE]
    stopifnot(nrow(c_int)==1)
    c_mass <- pracma::integral(fun = function(x){agg_fun(x)/tauc},
                               xmin = c_int$interval_start, 
                               xmax = c_int$interval_end,
                               no_intervals = 24)
    daily_integrals[c_indx, 'mass'] <- c_mass
    daily_integrals[c_indx, 'done'] <- 1

    result_ordering <- order(daily_integrals$interval_start)
    if (!all(result_ordering == 1:nrow(daily_integrals))){
      daily_integrals <- daily_integrals[result_ordering,]
    }

    if (daily_integrals$done[1] == 1){
      if (daily_integrals$mass[1] >= end_mass_thresh){
        daily_integrals <- rbind(
          data.frame(                       
            interval_start = (min(daily_integrals$interval_start)-expansion_size):(min(daily_integrals$interval_start)-1),
            interval_end = (min(daily_integrals$interval_end)-expansion_size):(min(daily_integrals$interval_end)-1),
            mass = -1,
            done = 0,
            stringsAsFactors = FALSE),
          daily_integrals)
      }
    }
    if (daily_integrals$done[nrow(daily_integrals)] == 1){
      if (daily_integrals$mass[nrow(daily_integrals)] >= end_mass_thresh){
        daily_integrals <- rbind(
          daily_integrals,
          data.frame(                       
            interval_start = (max(daily_integrals$interval_start) + 1):(max(daily_integrals$interval_start) + expansion_size),
            interval_end = (max(daily_integrals$interval_end) + 1):(max(daily_integrals$interval_end) + expansion_size),
            mass = -1,
            done = 0,
            stringsAsFactors = FALSE))
      }
    }
  }

  return(daily_integrals)
}

#' Basic function used for testing estimate_lb_med_ub
#'
#' Given a function and the lb, med and ub, verify that the lb, med and ub are correct.

check_lb_med_ub <- function(lb, med, ub, fun, range_start, range_end){
  if (FALSE){
    lb  = qbeta(0.025, 2, 5)
    med = qbeta(0.5,   2, 5)
    ub  = qbeta(0.975, 2, 5)
    fun = function(x){dbeta(x, 2, 5)}
    range_start = 0
    range_end = 1

    lb <- lb$minimum
    med <- med$minimum
    ub <- ub$minimum
  }
  total_aoc <- pracma::integral(f = fun,
                         xmin = range_start,
                         xmax = range_end,
                         no_intervals = 1000)
  area_left_of_lb <- pracma::integral(f = function(x){fun(x)/total_aoc},
                               xmin = range_start,
                               xmax = lb,
                               no_intervals = 1000)
  area_left_of_med <- pracma::integral(f = function(x){fun(x)/total_aoc},
                               xmin = range_start,
                               xmax = med,
                               no_intervals = 1000)
  area_left_of_ub <- pracma::integral(f = function(x){fun(x)/total_aoc},
                               xmin = range_start,
                               xmax = ub,
                               no_intervals = 1000)
  return(list(area_left_of_lb = area_left_of_lb,
              area_left_of_med = area_left_of_med,
              area_left_of_ub = area_left_of_ub))
}

