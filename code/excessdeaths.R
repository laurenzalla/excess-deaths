#Fit time series models to estimate expected and excess deaths in March-December 2020 by state and underlying COD
#Code adapted from Matthew Kiang: https://github.com/mkiang/excess_external_deaths

library(tidyverse)
library(forecast)

setwd("<filepath>")

## Constants
forecast_start <- as.Date("2020-03-01")
forecast_window <- 10 ## Predict from March 2020 to Dec 2020
forecast_year <- 2020

###UNSTANDARDIZED ESTIMATES

##Read in observed death counts from 2005-2020
deaths <- read.csv("deaths.csv") %>%
  mutate(date = as.Date(sprintf("%d-%02d-%02d",year, month, 01))) %>%
  mutate(deaths_st = deaths/(days*popest)*100000) %>% #express as rates (deaths per day per 100,000)
  filter(cod!="COVID") #No historical data for COVID

## Helper Function
return_fitted_and_predicted <- function(
    deaths,
    forecast_start,
    forecast_window,
    forecast_year,
    cod_x,
    state_x) {
  
  current_df <- deaths %>%
    filter(cod == cod_x,
           state == state_x)
  
  sub_df <- current_df %>%
    filter(date < forecast_start)
  
  tt <- ts(sub_df$deaths_st,
           deltat = 1 / 12,
           start = min(sub_df$year))
  
  # Fit model with up to six harmonic terms
  mm <- list(aicc = Inf)
  for (i in 1:6) {
    mm.i <- auto.arima(tt, xreg = fourier(tt, K = i), seasonal = FALSE)
    if (mm.i$aicc < mm$aicc) {
      mm <- mm.i
      k.best <- i
    }
  }
  
  fitted_df <- tibble(date = sub_df$date,
                      expected_st = fitted(mm))
  
  # Obtain forecasts
  ff <- forecast(mm, xreg = fourier(tt, K = k.best, h = forecast_window))
  
  # Extract observed death counts
  oo <- current_df[(forecast_start <= current_df$date) &
                     (current_df$date < (forecast_start + forecast_window * 30.25)),
                   c('date', "deaths")]

  ## Extract expected death counts and calculate excess deaths
  days <- c(31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  pop <- current_df$popest[which(current_df$year==forecast_year & current_df$month>2)]
  
  ee <- data.frame(
    date = seq(forecast_start, by = "month", length.out = 10),
    expected_st = as.numeric(ff$mean[1:10]),
    expected_st_lower = as.numeric(ff$lower[1:10, '95%']),
    expected_st_upper = as.numeric(ff$upper[1:10, '95%']))
  
  ee <- ee %>%
      mutate(cum_observed = sum(oo$deaths),
              expected = (expected_st*days*pop)/100000, #de-standardize
              expected_lower = (expected_st_lower*days*pop)/100000,
              expected_upper = (expected_st_upper*days*pop)/100000,
              cum_expected = sum(expected),
              excess = oo$deaths-expected,
              cum_excess = cum_observed-cum_expected)
  
  # Obtain prediction intervals for totals
  set.seed(94118)
  NN <- 10000
  SS <- NULL
  for (ii in 1:NN) {
    sim.i <- simulate(
      mm,
      future = TRUE,
      nsim = forecast_window,
      xreg = fourier(tt, K = k.best, h = forecast_window)
    )
    days <- c(31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
    pop <- current_df$popest[which(current_df$year==forecast_year & current_df$month>2)]
    monthtotal <- (sim.i*days*pop)/100000 #de-standardize the expected death counts
    SS.i <- data.frame(pt=sum(monthtotal))
    SS <- rbind(SS, SS.i)
  }
  
  current_df %>%
    left_join(bind_rows(fitted_df, ee)) %>% 
    mutate(cum_excess_lower = unname(quantile(sum(oo$deaths) - SS$pt, .025)),
           cum_excess_upper = unname(quantile(sum(oo$deaths) - SS$pt, .975)),
           cum_excess_mean = mean(sum(oo$deaths) - SS$pt))
}

## Fit and predict every combination of cause/state ----
if (!file.exists("excess_mortality_estimates.RDS")) {
  param_grid <- deaths %>% 
    select(cod, state) %>% 
    distinct()
  
  holder <- vector("list", NROW(param_grid))
  for (i in 1:NROW(holder)) {
    if (is.null(holder[[i]])) {
      holder[[i]] <-
        return_fitted_and_predicted(
          deaths,
          forecast_start,
          forecast_window,
          forecast_year,
          cod_x = param_grid$cod[i],
          state_x = param_grid$state[i]
        )
    }
  }
  
  ## Save ----
  holder <- bind_rows(holder)
  saveRDS(holder, "excess_mortality_estimates.RDS")
  write_csv(holder, "excess_mortality_estimates.csv")
}



##Check Model Fit
#Predict deaths for March 2019-December 2019
forecast_start <- as.Date("2019-03-01")
forecast_window <- 10
forecast_year <- 2019

## fit and predict for every combination of cause and region
if (!file.exists("model_fit.RDS")) {
  param_grid <- deaths %>% 
    select(cod, state) %>% 
    filter(state %in% c("R1","R2","R3","R4")) %>%
    distinct()
  
  holder <- vector("list", NROW(param_grid))
  for (i in 1:NROW(holder)) {
    if (is.null(holder[[i]])) {
      holder[[i]] <-
        return_fitted_and_predicted(
          deaths,
          forecast_start,
          forecast_window,
          forecast_year,
          cod_x = param_grid$cod[i],
          state_x = param_grid$state[i]
        )
    }
  }
  
  ## Save ----
  holder <- bind_rows(holder)
  saveRDS(holder, "model_fit.RDS")
  write_csv(holder, "model_fit.csv")
}



###AGE-STANDARDIZED ESTIMATES
forecast_start <- as.Date("2020-03-01")
forecast_window <- 10 ## Predict from March 2020 to Dec 2020
forecast_year <- 2020

##Read in age-standardized death rates (expressed as deaths/100,000)
deaths <- read.csv("deaths_agest.csv") %>%
  mutate(date = as.Date(sprintf("%d-%02d-%02d",year, month, 01))) %>%
  mutate(deaths_agest = deathrate_agest/days) %>% #express as deaths per day per 100,000
  filter(cod!="COVID") #No historical data for COVID

## Helper Function
return_fitted_and_predicted <- function(
    deaths,
    forecast_start,
    forecast_window,
    forecast_year,
    cod_x,
    state_x) {
  
  current_df <- deaths %>%
    filter(cod == cod_x,
           state == state_x)
  
  sub_df <- current_df %>%
    filter(date < forecast_start)
  
  tt <- ts(sub_df$deaths_agest,
           deltat = 1 / 12,
           start = min(sub_df$year))
  
  # Fit model with up to six harmonic terms
  mm <- list(aicc = Inf)
  for (i in 1:6) {
    mm.i <- auto.arima(tt, xreg = fourier(tt, K = i), seasonal = FALSE)
    if (mm.i$aicc < mm$aicc) {
      mm <- mm.i
      k.best <- i
    }
  }
  
  fitted_df <- tibble(date = sub_df$date,
                      expected_st = fitted(mm))
  
  # Obtain forecasts
  ff <- forecast(mm, xreg = fourier(tt, K = k.best, h = forecast_window))
  
  # Extract observed death rates
  oo <- current_df[(forecast_start <= current_df$date) &
                     (current_df$date < (forecast_start + forecast_window * 30.25)),
                   c('date', "deathrate_agest")]
  

  ## Extract expected death rates and calculate excess death rates
  days <- c(31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  
  ee <- data.frame(
    date = seq(forecast_start, by = "month", length.out = 10),
    expected_agest = as.numeric(ff$mean[1:10]),
    expected_agest_lower = as.numeric(ff$lower[1:10, '95%']),
    expected_agest_upper = as.numeric(ff$upper[1:10, '95%']))
  
  ee <- ee %>%
    mutate(cum_observed = sum(oo$deathrate_agest),
           cum_expected = sum(expected_agest*days),
           cum_excess = cum_observed-cum_expected)
  
  
  # Obtain prediction intervals for totals (total excess deaths per 100,000 standard pop)
  set.seed(94118)
  NN <- 10000
  SS <- NULL
  for (ii in 1:NN) {
    sim.i <- simulate(
      mm,
      future = TRUE,
      nsim = forecast_window,
      xreg = fourier(tt, K = k.best, h = forecast_window)
    )
    days <- c(31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
    monthtotal <- (sim.i*days) #de-standardize by # days/month
    SS.i <- data.frame(pt=sum(monthtotal))
    SS <- rbind(SS, SS.i)
  }
  
  current_df %>%
    left_join(bind_rows(fitted_df, ee)) %>% 
    mutate(cum_excess_lower = unname(quantile(sum(oo$deathrate_agest) - SS$pt, .025)),
           cum_excess_upper = unname(quantile(sum(oo$deathrate_agest) - SS$pt, .975)),
           cum_excess_mean = mean(sum(oo$deathrate_agest) - SS$pt))
}

## Fit and predict every combination of cause/state ----
if (!file.exists("excess_mortality_estimates_agest.RDS")) {
  param_grid <- deaths %>% 
    select(cod, state) %>% 
    distinct()
  
  holder <- vector("list", NROW(param_grid))
  for (i in 1:NROW(holder)) {
    if (is.null(holder[[i]])) {
      holder[[i]] <-
        return_fitted_and_predicted(
          deaths,
          forecast_start,
          forecast_window,
          forecast_year,
          cod_x = param_grid$cod[i],
          state_x = param_grid$state[i]
        )
    }
  }
  
  ## Save ----
  holder <- bind_rows(holder)
  saveRDS(holder, "excess_mortality_estimates_agest.RDS")
  write_csv(holder, "excess_mortality_estimates_agest.csv")
}
