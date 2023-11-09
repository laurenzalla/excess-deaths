# excess-deaths
Estimate the number of excess deaths from 17 underlying causes of death from March-December 2020 by fitting time series models to NCHS restricted-use mortality data for 2005-2020.

**Data:**
- NCHS Multiple Cause of Death Micro-Data: https://www.cdc.gov/nchs/nvss/dvs_data_release.htm
- U.S. Census Population Estimates: https://www2.census.gov/programs-surveys/popest/datasets/
  
**Code:**
- import.sas: Import mortality micro-data.
- analysis.sas: Create analytic dataset; output tables and figures.
- excessdeaths.R: Fit time series models to estimate expected and excess death rates by month, state/region, and underlying cause of death.

**Results:**
- summary.csv: Observed, expected, and excess death counts and rates, and correlation between the trend in excess deaths and the trend in deaths from COVID-19, by underlying cause of death and state or geographic region. Note: observed deaths counts between 1-9, and corresponding expected death counts, are suppressed in compliance with the Public Health Services Act (42 U.S.C. 242m(d)).
- ExpectedDeathsByCOD.pptx: Plots of observed and expected death rates by year, month, underlying cause of death, and geographic region. Note: state-level data are suppressed in compliance with the Public Health Services Act (42 U.S.C. 242m(d)).
- ExcessDeathsByCOD.pptx: Plots of excess death counts by month, underlying cause of death, and state or geographic region.
- ModelFit.pptx: Visual assessment of model fit based on observed vs. model-predicted death rates from March-December 2019.
