*Project: Estimate excess deaths by state/region and underlying cause of death based on death counts from 2005-2019;
*Data: NCHS Restricted Use Detailed Mortality Files + Census Population Estimates;

%let source=<filepath>;
%include "&source.\formats.sas";
libname data "&source.";

*Examine Data;
proc contents data=data.mort0520; run;
proc freq data=data.mort0520; tables datayear; where state_occ notin("PR","GU","VI","AS","MP"); run;
proc freq data=data.mort0520; tables icd39; where state_occ notin("PR","GU","VI","AS","MP"); run;
proc freq data=data.mort0520; tables icd*icd39; where icd in("U070","U071") and state_occ notin("PR","GU","VI","AS","MP"); ; run;

data ucod (drop=agedtl rename=(datayear=year state_occ=state));
set data.mort0520 (keep=datayear month state_occ age icd icd39 rename=(age=agedtl));
*Restrict to 50 US States;
where state_occ notin("PR","GU","VI","AS","MP");

*Region;
if state_occ in("DE","DC","MD","NJ","NY","PA","CT","ME","MA","NH","RI","VT") then region="R1";									*Mideast and New England;
if state_occ in("AL","AR","FL","GA","KY","LA","MS","NC","SC","TN","VA","WV","AZ","NM","OK","TX") then region="R2";				*Southeast and Southwest;
if state_occ in("AK","CA","HI","NV","OR","WA","IA","KS","MN","MO","NE","ND","SD","CO","ID","MT","UT","WY") then region="R3"; 	*Far West, Plains, Rocky Mountain;
if state_occ in("IL","IN","MI","OH","WI") then region="R4";																		*Great Lakes;

*Underlying COD;
if icd="U071" then cod=0; 							*COVID-19;
*else if icd in("X40", "X41", "X42", "X43", "X44", "X60", "X61", "X62", "X63", "X64", "X85", "Y10", "Y11", "Y12", "Y13", "Y14") then cod=1; *Overdose;
*Note: overdose deaths are distributed among suicide, homicide, and other external causes in the ICD-39. Here, they are classified as overdose deaths regardless of circumstance or intent.;
else if icd39=40 then cod=2;						*Suicide;
else if icd39=41 then cod=3;						*Homicide;
else if icd39=38 then cod=4;						*Motor Vehicle Accidents;
else if icd39=39 or substr(icd,1,3) in("Y35","Y36","Y89") then cod=5;	*Other External Causes;
else if icd39 in(5:15) then cod=6; 					*Cancer;
else if icd39=16 then cod=7;						*Diabetes;
else if icd39=17 then cod=8;						*Alzheimer's Disease;
else if icd39 in(20:26) then cod=9;					*Cardiovascular Disease;
else if icd39=27 then cod=10;						*Influence/Pneumonia;
else if icd39=28 then cod=11;						*Chronic Lower Respiratory Disease;
else if icd39=3 then cod=12;						*HIV;
else if icd39=30 then cod=13;						*Liver Disease;
else if icd39=31 then cod=14;						*Kidney Disease;
else if icd39 in (1,2,29,32:35,37) or icd="U070" then cod=15;	*Other Diseases - Includes TB, Syphilis, Peptic Ulcer, Pregnancy & Childbirth, Infant Mortality, Vaping-Related Disorder;
else if icd39=42 and substr(icd,1,3) notin("Y35","Y36","Y89") then cod=17;	*Injury of Undetermined Intent;
else if icd39=36 then cod=18;						*Unknown Disease;

*Age;
if agedtl in(1999,9999) then age=.;
else if agedtl in(1000,2000:6999) then age=0;
else if agedtl<1999 then age=agedtl-1000;
if age>85 then age=85; *truncate at age 85 to match population estimates from US Census;
run;

*Checks;
proc freq data=ucod; tables cod / missing; format cod cod.; run;
proc freq data=ucod; tables cod*icd39 / missing; format cod cod.; run;
proc sort data=ucod; by cod; run;
proc freq data=ucod; by cod; tables icd / missing; format cod cod.; run;
proc freq data=ucod; tables cod; where year=2020; format cod cod.; run;
proc freq data=ucod; tables age; run;
*Frequency of zero cells by COD;
ods exclude all;
proc freq data=ucod; tables year*month*state*icd39 / out=freq sparse; run;
ods exclude none;
data zeros; set freq; if count=0 then zero=1; else zero=0; run;
proc freq data=zeros; tables icd39*zero / nofreq nocol nopercent; run;
*Percent of total deaths by COD;
proc freq data=ucod; tables icd39; where year<2020; run;
*List of states by region; proc freq data=ucod; tables state*region / missing; run;


***UNSTANDARDIZED DEATH COUNTS***;
*Output count of deaths by month, state, region, and underlying COD;
ods exclude all;
proc freq data=ucod; tables year*month*state*cod / out=state(drop=percent rename=(count=deaths)) sparse; run;
proc freq data=ucod; tables year*month*region*cod / out=region(drop=percent rename=(count=deaths)) sparse; run;
ods exclude none;
data counts; set region(rename=(region=state)) state; run;

*Add total rows;
proc sort data=counts; by year month state cod; run;
data allcauses (keep=year month state sum1); set counts; retain sum1; by year month state cod; if first.state then sum1=deaths; else sum1=sum1+deaths; if last.state then output; run;
data allcauses; set allcauses; rename sum1=deaths; cod=16; run;
proc sort data=counts; by year month cod state; run;
data allstates (keep=year month cod sum2); set counts; where state notin("R1","R2","R3","R4"); retain sum2; by year month cod state; if first.cod then sum2=deaths; else sum2=sum2+deaths; if last.cod then output; run;
data allstates; set allstates; rename sum2=deaths; state="US"; run;
proc sort data=counts; by year month; run;
data allstatesallcauses (keep=year month sum3); set counts; where state notin("R1","R2","R3","R4"); retain sum3; by year month; if first.month then sum3=deaths; else sum3=sum3+deaths; if last.month then output; run;
data allstatesallcauses; set allstatesallcauses; rename sum3=deaths; cod=16; state="US"; run;
data counts; set counts allcauses allstates allstatesallcauses; run;
proc print data=counts (obs=17); where state="US" and year=2020; run;
proc means data=counts sum; var deaths; where cod=16 and year=2020 and state="US"; run; *Total - all causes;
proc means data=counts sum; var deaths; where cod=0 and year=2020 and state="US"; run; *Total - COVID-19;
proc print data=counts (obs=55); where cod=0 and year=2020; run;

*Merge in population data from 2004-2021;
proc import datafile="&source.\nst-est2010.csv" out=popraw10(drop=popestimate2010) dbms=csv replace; getnames=yes; run;
proc import datafile="&source.\nst-est2020.csv" out=popraw20 dbms=csv replace; getnames=yes; run;
proc import datafile="&source.\nst-est2022.csv" out=popraw22 dbms=csv replace; getnames=yes; run;

*Expand to one row per month, distributing annual population change evenly across months;
data popraw22; length name $20.; set popraw22; if name="District of Columb" then name="District of Columbia"; run;
proc sort data=popraw10; by name; run; proc sort data=popraw20; by name; run; proc sort data=popraw22; by name; run;
data popraw (keep=name popestimate2004-popestimate2021); length name $35.; merge popraw10 popraw20 popraw22; by name; where sumlev in(10,40) and name ne "Puerto Rico"; run;
proc transpose data=popraw out=long(rename=(col1=popyear)); by name; run;
data long (drop=_name_); set long; year=input(substr(_name_,12,4),8.); run;
proc sort data=long; by name year; run;
data long; set long; by name year; lastyear=lag(popyear); if first.name then lastyear=.; run;
data long (drop=i year);
set long;
where year in(2005:2021);
by name year;
diff=popyear-lastyear;
do i=1 to 12;
popest=lastyear+((diff/12)*i);
*Shift backward 6 months (since population estimates are for July 1);
if i in(1:6) then do; year2=year-1; month=i+6; end;
if i in(7:12) then do; year2=year; month=i-6; end;
output;
end;
format popest 8.0;
run;
data long (rename=(year2=year)); set long; where 2020>=year2>=2005; run;
proc sort data=long; by name year month; run;
proc freq data=long; tables name; run;

data popest (rename=(name=statename));
length name $35.;
set long (keep=name year month popest);
if name="United States" then state="US"; if name="Alabama" then state="AL"; if name="Alaska" then state="AK"; if name="Arizona" then state="AZ";
if name="Arkansas" then state="AR"; if name="California" then state="CA"; if name="Colorado" then state="CO"; if name="Connecticut" then state="CT";
if name="Delaware" then state="DE"; if name="District of Columbia" then state="DC"; if name="Florida" then state="FL"; if name="Georgia" then state="GA";
if name="Hawaii" then state="HI"; if name="Idaho" then state="ID"; if name="Illinois" then state="IL"; if name="Indiana" then state="IN";
if name="Iowa" then state="IA"; if name="Kansas" then state="KS"; if name="Kentucky" then state="KY"; if name="Louisiana" then state="LA";
if name="Maine" then state="ME"; if name="Maryland" then state="MD"; if name="Massachusetts" then state="MA"; if name="Michigan" then state="MI";
if name="Minnesota" then state="MN"; if name="Mississippi" then state="MS"; if name="Missouri" then state="MO"; if name="Montana" then state="MT";
if name="Nebraska" then state="NE"; if name="Nevada" then state="NV"; if name="New Hampshire" then state="NH"; if name="New Jersey" then state="NJ";
if name="New Mexico" then state="NM"; if name="New York" then state="NY"; if name="North Carolina" then state="NC"; if name="North Dakota" then state="ND";
if name="Ohio" then state="OH"; if name="Oklahoma" then state="OK"; if name="Oregon" then state="OR"; if name="Pennsylvania" then state="PA";
if name="Rhode Island" then state="RI"; if name="South Carolina" then state="SC"; if name="South Dakota" then state="SD"; if name="Tennessee" then state="TN";
if name="Texas" then state="TX"; if name="Utah" then state="UT"; if name="Vermont" then state="VT"; if name="Virginia" then state="VA";
if name="Washington" then state="WA"; if name="West Virginia" then state="WV"; if name="Wisconsin" then state="WI"; if name="Wyoming" then state="WY";

if state in("DE","DC","MD","NJ","NY","PA","CT","ME","MA","NH","RI","VT") then region="R1";
if state in("AL","AR","FL","GA","KY","LA","MS","NC","SC","TN","VA","WV","AZ","NM","OK","TX") then region="R2";
if state in("AK","CA","HI","NV","OR","WA","IA","KS","MN","MO","NE","ND","SD","CO","ID","MT","UT","WY") then region="R3";
if state in("IL","IN","MI","OH","WI") then region="R4";
format name; informat name;
run;
proc sort data=popest; by region year month; run;
ods select none;
proc means data=popest sum; where state ne "US"; by region year month; var popest; output out=region(drop=_TYPE_ _FREQ_ rename=(region=state)) sum(popest)=popest; run;
ods select all;
data region;
length statename $35.;
set region;
if state="R1" then statename="Mideast and New England";
if state="R2" then statename="Southeast and Southwest";
if state="R3" then statename="Far West, Plains and Rocky Mountain";
if state="R4" then statename="Great Lakes";
run;
data popest; set popest(drop=region) region; run;

proc sort data=counts; by state year month; run; proc sort data=popest; by state year month; run;
data merged; merge counts popest; by state year month;

data merged;
set merged;
*add # days per month - will standardize monthly counts by # days per month prior to modeling;
if year in (2008, 2012, 2016, 2020) and month=2 then days=29;
else if month=2 then days=28;
else if month in (1,3,5,7,8,10,12) then days=31;
else if month in (4,6,9,11) then days=30;
format cod cod.;
run;

*Export to CSV;
proc export data=merged outfile="&source.\deaths.csv" dbms=csv replace; run;



***AGE-STANDARDIZED DEATH COUNTS***;
*Counts of deaths are standardized to the national population age distribution in 2020;
*Output count of deaths by month, state, region, age, and underlying COD;
*Exclude 5,387 deaths with missing age (0.01%);
ods exclude all;
proc freq data=ucod; tables year*month*state*age*cod / out=state(drop=percent rename=(count=deaths)) sparse; where age ne .; run;
proc freq data=ucod; tables year*month*region*age*cod / out=region(drop=percent rename=(count=deaths)) sparse; where age ne .; run;
ods exclude none;
data counts_age; set region(rename=(region=state)) state; run;
proc print data=counts_age (obs=10); run;

*Add total rows - within age groups;
proc sort data=counts_age; by year month state age cod; run;
data allcauses (keep=year month state age sum1); set counts_age; retain sum1; by year month state age cod; if first.age then sum1=deaths; else sum1=sum1+deaths; if last.age then output; run;
data allcauses; set allcauses; rename sum1=deaths; cod=16; run;
proc sort data=counts_age; by year month cod age state; run;
data allstates (keep=year month cod age sum2); set counts_age; where state notin("R1","R2","R3","R4"); retain sum2; by year month cod age state; if first.age then sum2=deaths; else sum2=sum2+deaths; if last.age then output; run;
data allstates; set allstates; rename sum2=deaths; state="US"; run;
proc sort data=counts_age; by year age month; run;
data allstatesallcauses (keep=year age month sum3); set counts_age; where state notin("R1","R2","R3","R4"); retain sum3; by year age month; if first.month then sum3=deaths; else sum3=sum3+deaths; if last.month then output; run;
data allstatesallcauses; set allstatesallcauses; rename sum3=deaths; cod=16; state="US"; run;
data counts_age; set counts_age allcauses allstates allstatesallcauses; run;
proc print data=counts_age (obs=17); where state="US" and year=2020; run;
proc means data=counts_age sum; var deaths; where cod=16 and year=2020 and state="US"; run;
proc means data=counts_age sum; var deaths; where cod=0 and year=2020 and state="US"; run;
proc print data=counts_age (obs=55); where cod=0 and year=2020; run;

*Merge in state population estimates by single year of age for 2020;
proc import datafile="&source.\sc-est2009-agesex-civ.csv" out=popraw10 dbms=csv replace; getnames=yes; run;
proc import datafile="&source.\sc-est2020-agesex-civ.csv" out=popraw20(drop=popest2020_civ) dbms=csv replace; getnames=yes; run;
proc import datafile="&source.\sc-est2022-agesex-civ.csv" out=popraw22 dbms=csv replace; getnames=yes; run;
data popraw10; length name $35.; set popraw10; if name="District of C" then name="District of Columbia"; if name="South Carolin" then name="South Carolina"; if name="North Carolin" then name="North Carolina"; run;
data popraw20; length name $35.; set popraw20; if name="District of C" then name="District of Columbia"; if name="South Carolin" then name="South Carolina"; if name="North Carolin" then name="North Carolina"; run;
data popraw22; length name $35.; set popraw22; if name="District of C" then name="District of Columbia"; if name="South Carolin" then name="South Carolina"; if name="North Carolin" then name="North Carolina"; run;

*Expand to one row per month, distributing annual population change evenly across months;
proc sort data=popraw10; by name age; run; proc sort data=popraw20; by name age; run; proc sort data=popraw22; by name age; run;
data popraw (keep=name age popest2004_civ popest2005_civ popest2006_civ popest2007_civ popest2008_civ popest2009_civ popest2010_civ popest2011_civ popest2012_civ popest2013_civ popest2014_civ popest2014_civ popest2015_civ popest2016_civ popest2017_civ popest2018_civ popest2019_civ popest2020_civ popest2021_civ);
merge popraw10 popraw20 popraw22;
by name age;
where sumlev in(10,40) and name ne "Puerto Rico" and sex=0;
format name $35.;
run;
proc sort data=popraw; by name age; run;
proc transpose data=popraw out=long(rename=(col1=popyear)); by name age; run;
data long (drop=_name_ col2); set long; year=input(substr(_name_,7,4),8.); run;
proc sort data=long; by name age year; run;
data long; set long; by name age year; lastyear=lag(popyear); if first.age then lastyear=.; run;
data long (drop=i year);
set long;
where year in(2005:2021);
by name age year;
diff=popyear-lastyear;
do i=1 to 12;
popest=lastyear+((diff/12)*i);
*Shift backward 6 months (since population estimates are for July 1);
if i in(1:6) then do; year2=year-1; month=i+6; end;
if i in(7:12) then do; year2=year; month=i-6; end;
output;
end;
format popest 8.0;
run;
data long (rename=(year2=year)); set long; where 2020>=year2>=2005; run;
proc print data=long (obs=100); run;

data popest_age (rename=(name=statename));
length name $35.;
set long (keep=name year month age popest);
if name="United States" then state="US"; if name="Alabama" then state="AL"; if name="Alaska" then state="AK"; if name="Arizona" then state="AZ";
if name="Arkansas" then state="AR"; if name="California" then state="CA"; if name="Colorado" then state="CO"; if name="Connecticut" then state="CT";
if name="Delaware" then state="DE"; if name="District of Columbia" then state="DC"; if name="Florida" then state="FL"; if name="Georgia" then state="GA";
if name="Hawaii" then state="HI"; if name="Idaho" then state="ID"; if name="Illinois" then state="IL"; if name="Indiana" then state="IN";
if name="Iowa" then state="IA"; if name="Kansas" then state="KS"; if name="Kentucky" then state="KY"; if name="Louisiana" then state="LA";
if name="Maine" then state="ME"; if name="Maryland" then state="MD"; if name="Massachusetts" then state="MA"; if name="Michigan" then state="MI";
if name="Minnesota" then state="MN"; if name="Mississippi" then state="MS"; if name="Missouri" then state="MO"; if name="Montana" then state="MT";
if name="Nebraska" then state="NE"; if name="Nevada" then state="NV"; if name="New Hampshire" then state="NH"; if name="New Jersey" then state="NJ";
if name="New Mexico" then state="NM"; if name="New York" then state="NY"; if name="North Carolina" then state="NC"; if name="North Dakota" then state="ND";
if name="Ohio" then state="OH"; if name="Oklahoma" then state="OK"; if name="Oregon" then state="OR"; if name="Pennsylvania" then state="PA";
if name="Rhode Island" then state="RI"; if name="South Carolina" then state="SC"; if name="South Dakota" then state="SD"; if name="Tennessee" then state="TN";
if name="Texas" then state="TX"; if name="Utah" then state="UT"; if name="Vermont" then state="VT"; if name="Virginia" then state="VA";
if name="Washington" then state="WA"; if name="West Virginia" then state="WV"; if name="Wisconsin" then state="WI"; if name="Wyoming" then state="WY";

if state in("DE","DC","MD","NJ","NY","PA","CT","ME","MA","NH","RI","VT") then region="R1";
if state in("AL","AR","FL","GA","KY","LA","MS","NC","SC","TN","VA","WV","AZ","NM","OK","TX") then region="R2";
if state in("AK","CA","HI","NV","OR","WA","IA","KS","MN","MO","NE","ND","SD","CO","ID","MT","UT","WY") then region="R3";
if state in("IL","IN","MI","OH","WI") then region="R4";
format name; informat name;
run;
*Get regional totals;
proc sort data=popest_age; by region year month age; run;
ods select none;
proc means data=popest_age sum; where state ne "US"; by region year month age; var popest; output out=region(drop=_TYPE_ _FREQ_ rename=(region=state)) sum(popest)=popest; run;
ods select all;
data region;
length statename $35.;
set region;
if state="R1" then statename="Mideast and New England";
if state="R2" then statename="Southeast and Southwest";
if state="R3" then statename="Far West, Plains and Rocky Mountain";
if state="R4" then statename="Great Lakes";
run;
data popest_age; set popest_age(drop=region) region; run;

proc sort data=counts_age; by state year month age; run; proc sort data=popest_age; by state year month age; run;
data merged_age; merge counts_age popest_age; by state year month age;
where age ne 999;
format cod cod.;
run;

*Age-standardize by national age distribution (ASMR);
*Calculate proportion of total population in each single year of age (p), by month, in 2020;
data national (keep=month age popest); set popest_age; where state="US" and age ne 999 and year=2020; run;
data total (keep=month popest rename=(popest=totalpop)); set popest_age; where state="US" and age=999 and year=2020; run;
data stdpop (drop=popest totalpop); merge national total; by month; p=popest/totalpop; run;
proc print data=stdpop; run;
proc sort data=stdpop; by month; run;
*Merge with death counts;
proc sort data=merged_age; by month age; run; proc sort data=stdpop; by month age; run;
data merged_age;
merge merged_age stdpop;
by month age;
*Calculate unadjusted rate per 100,000;
deathrate=(deaths/popest)*100000;
*Calculate age-standardized death rate by multiplying age-specific rates * p, then summing across all ages;
deathrate_wt=deathrate*p;
run;
proc sort data=merged_age; by state year month cod age; run;
data merged_age (drop=age popest p deaths deathrate deathrate_wt p);
set merged_age;
by state year month cod age;
retain deathrate_agest;
if first.cod then deathrate_agest=deathrate_wt;
else deathrate_agest=deathrate_agest+deathrate_wt;
if last.cod then output;
run;
data merged_age; set merged_age;
*add # days per month - will standardize monthly rates by # days per month prior to modeling;
if year in (2008, 2012, 2016, 2020) and month=2 then days=29;
else if month=2 then days=28;
else if month in (1,3,5,7,8,10,12) then days=31;
else if month in (4,6,9,11) then days=30;
run;

*Export to CSV;
proc export data=merged_age outfile="&source.\deaths_agest.csv" dbms=csv replace; run;


***NOTE: All modeling done in R (see excessdeaths.R)***;
*Expected deaths per day per 100,000 population modeled using dynamic harmonic regression models with ARIMA errors in R;
*Import estimates from R;
proc import datafile="&source.\excess_mortality_estimates.csv" out=expected replace; guessingrows=190000; run;
data expected (drop=expected_st_lower expected_st_upper expected expected_lower expected_upper cum_observed cum_expected excess cum_excess
rename=(expected2=expected expected_lower2=expected_lower expected_upper2=expected_upper cum_observed2=cum_observed cum_expected2=cum_expected excess2=excess cum_excess2=cum_excess));
set expected;
*Convert character variables to numeric;
if expected_st_lower="NA" then expected_st_lower=""; if expected_st_upper="NA" then expected_st_upper="";
if expected="NA" then expected=""; if expected_lower="NA" then expected_lower=""; if expected_upper="NA" then expected_upper="";
if cum_observed="NA" then cum_observed=""; if cum_expected="NA" then cum_expected=""; if excess="NA" then excess=""; if cum_excess="NA" then cum_excess="";
predicted_st_lower=input(expected_st_lower, 8.); predicted_st_upper=input(expected_st_upper, 8.);
expected2=input(expected, 8.); expected_lower2=input(expected_lower, 8.); expected_upper2=input(expected_upper, 8.);
cum_observed2=input(cum_observed, 8.); cum_expected2=input(cum_expected, 8.); excess2=input(excess, 8.); cum_excess2=input(cum_excess, 8.);

*Separate model estimates (before March 2020) vs. projections (after March 2020);
if year=2020 and month>2 then do; predicted_st=expected_st; predicted_st_lower=expected_st_lower; predicted_st_upper=expected_st_upper; excess_st=deaths_st-expected_st; expected_st=.; end;
else do; histdeaths_st=deaths_st; deaths_st=.; end;

*Cumulative number of excess deaths from March-December 2020;
if year ne 2020 | month ne 12 then do; cum_observed2=.; cum_expected2=.; cum_excess2=.; cum_excess_mean=.; cum_excess_lower=.; cum_excess_upper=.; end;

format deaths_st expected_st predicted_st predicted_st_lower predicted_st_upper excess_st histdeaths_st 8.2 expected excess cum_observed cum_expected cum_excess cum_excess_mean cum_excess_lower cum_excess_upper 8.0;
run;
proc print data=expected (obs=12); where year=2020 and state="US" and cod="All Causes"; run;
proc means data=expected sum; var deaths; where year=2020 and state="US" and cod="All Causes"; run;

*'Difference' the time series and calculate correlation coefficients between excess deaths from each non-COVID cause of death and observed deaths from COVID-19;
*Calculate month-to-month differences in excess non-COVID deaths (standardized by #days/month);
data excess (keep=state cod2 month days excess);
set expected;
where year=2020 and month in(3:12);
if cod="Suicide" then cod2=2; else if cod="Homicide" then cod2=3; else if cod="Motor Vehicle Accidents" then cod2=4; else if cod="Other External Causes" then cod2=5;
else if cod="Cancer" then cod2=6; else if cod="Diabetes" then cod2=7; else if cod="Alzheimers Disease" then cod2=8; else if cod="Cardiovascular Disease" then cod2=9;
else if cod="Influenza and Pneumonia" then cod2=10; else if cod="CLRD" then cod2=11; else if cod="HIV" then cod2=12;
else if cod="Liver Disease" then cod2=13; else if cod="Kidney Disease" then cod2=14; else if cod="Other Internal Causes" then cod2=15; else if cod="All Causes" then cod2=16;
else if cod="Injury of Undetermined Intent" then cod2=17; else if cod="Unknown Disease" then cod2=18;
run;
data excess; set excess(rename=(cod2=cod)); run;
proc sort data=excess; by state cod month; run;
data excess;
set excess;
by state cod month;
excess_st=excess/days; *standardize by # days/month;
lagexcess_st=lag(excess_st);
diff=excess_st-lagexcess_st;
if first.cod then diff=excess_st;
run;
proc sort data=excess; by state month; run;
proc transpose data=excess out=wide(drop=_NAME_ _LABEL_) prefix=cod; by state month; id cod; var diff; run;
*Calculate month-to-month differences in observed COVID deaths (standardized by # days/month);
data covid(keep=state month deaths); set counts; where year=2020 and month in(2:12) and cod=0; run;
proc sort data=covid; by state month; run;
data covid(keep=state month cod0); set covid;
by state month;
if month=2 then days=29; else if month in(3,5,7,8,10,12) then days=31; else days=30;
covid_st=deaths/days; *standardize by # days/month;
lagcovid_st=lag(covid_st);
cod0=covid_st-lagcovid_st;
if first.state then delete;
run;
*Merge;
data corr; merge covid wide; by state month; run;
*Estimate pearson correlation coefficients;
ods select none;
proc corr data=corr outp=pcorr; by state; var cod2-cod18; with cod0; run;
ods select all;
data pcorr(drop=_TYPE_ _NAME_); set pcorr; where _TYPE_="CORR"; run;
proc sort data=pcorr; by state; run;
proc transpose data=pcorr out=corr(rename=(COL1=corr)); by state; run;
data corr (keep=state cod corr);
length cod $33.;
set corr;
cod2=input(substr(_NAME_,4,2),8.);
if cod2=2 then cod="Suicide"; if cod2=3 then cod="Homicide"; if cod2=4 then cod="Motor Vehicle Accidents"; if cod2=5 then cod="Other External Causes";
if cod2=6 then cod="Cancer"; if cod2=7 then cod="Diabetes"; if cod2=8 then cod="Alzheimers Disease"; if cod2=9 then cod="Cardiovascular Disease";
if cod2=10 then cod="Influenza and Pneumonia"; if cod2=11 then cod="CLRD"; if cod2=12 then cod="HIV"; if cod2=13 then cod="Liver Disease";
if cod2=14 then cod="Kidney Disease"; if cod2=15 then cod="Other Internal Causes"; if cod2=16 then cod="All Causes"; if cod2=17 then cod="Injury of Undetermined Intent";
if cod2=18 then cod="Unknown Disease";
run;


***FIGURES***;
*Plot observed (January 2005-February 2020) and predicted (March-December 2020) deaths/day/100,000 by underlying COD;
proc template;
define style styles.mystyle;
	parent = styles.journal;
	class SystemTitle / fontfamily="Arial" fontsize=12pt fontstyle=roman fontweight=medium;
	class SystemFooter / fontfamily="Arial" fontsize=10pt fontstyle=roman fontweight=medium;
	end;
run;

%macro plot(state=,cod=,name=,xlabel=,ylabel=);

data plot; set expected; where state="&state" and cod="&cod.";

*Specify values for broken axis [largest and smallest values of historical or predicted deaths/(#days/month)];
proc means data=plot noprint min max; var histdeaths_st predicted_st deaths_st; output out=range(drop=_type_ _freq_) min(histdeaths_st)=minh max(histdeaths_st)=maxh min(predicted_st)=minp max(predicted_st)=maxp min(deaths_st)=mind max(deaths_st)=maxd; run;

	data _null_; set range;
	if minh<=minp and minh<=mind then call symput('min',minh);
	if minp<=minh and minp<=mind then call symput('min',minp);
	if mind<=minh and mind<=minp then call symput('min',mind);

	if maxh>=maxp and maxh>=maxd then call symput('max',maxh);
	if maxp>=maxh and maxp>=maxd then call symput('max',maxp);
	if maxd>=maxh and maxd>=maxp then call symput('max',maxd);

	run;

title "&name.";
proc sgplot data=plot noborder noautolegend;
styleattrs axisextent=data axisbreak=bracket
datacontrastcolors=(cxfafa6e cxd9f271 cxb9e976 cx9cdf7c cx7fd482 cx64c987 cx4abd8c cx30b08e cx14a38f cx00968e cx00898a cx007b84 cx106e7c cx1d6172 cx265466 cx2a4858);
*colors: https://colordesigner.io/gradient-generator;
series x=month y=histdeaths_st / group=year lineattrs=(pattern=solid);
series x=month y=predicted_st / lineattrs=(color=red pattern=dash thickness=2) break;
band x=month lower=predicted_st_lower upper=predicted_st_upper / fillattrs=(color=red transparency=0.9);
series x=month y=deaths_st / lineattrs=(color=black thickness=2);
xaxis &xlabel. values=(1 to 12 by 1);
yaxis &ylabel. min=&min. max=&max.;
run;

%mend;

title;
ods html close;
options nodate nonumber orientation=landscape;
ods powerpoint file="&source.\ExpectedDeathsByCOD.pptx" style=mystyle startpage=no;

%macro loop(state=, statename=);
*All Causes;
data plot; set expected; where state="&state." and cod="All Causes"; run;
ods powerpoint startpage=now;
title height=14pt "&statename.";
title2 height=12pt "Observed and Predicted Deaths/Day/100,000 Population from All Causes";
ods graphics / noborder width=12in height=8in maxlegendarea=100;
ods layout gridded columns=1 rows=1 y=0.25in;
ods region;
proc sgplot data=plot noborder noautolegend;
title;
styleattrs axisextent=data axisbreak=bracket datacontrastcolors=(cxfafa6e cxd9f271 cxb9e976 cx9cdf7c cx7fd482 cx64c987 cx4abd8c cx30b08e cx14a38f cx00968e cx00898a cx007b84 cx106e7c cx1d6172 cx265466 cx2a4858);
series x=month y=histdeaths_st / name="observed" group=year lineattrs=(pattern=solid);
series x=month y=predicted_st / name="predicted" lineattrs=(color=red pattern=dash thickness=2) break;
band x=month lower=predicted_st_lower upper=predicted_st_upper / fillattrs=(color=red transparency=0.9);
legenditem type=fill name="interval" / label="95% Prediction Interval" fillattrs=(color=red transparency=0.9);
series x=month y=deaths_st / name="pandemic" lineattrs=(color=black thickness=2);
xaxis label="Month" values=(1 to 12 by 1);
yaxis label="Deaths per Day per 100,000 Population";
label predicted_st="March 1-December 31, 2020 (Predicted)";
label deaths_st="March 1-December 31, 2020 (Observed)";
keylegend "observed" / down=2 valueattrs=(size=12) noborder position=bottomleft location=outside outerpad=(top=10 left=0 right=0 bottom=0);
keylegend "predicted" / valueattrs=(size=12) noborder position=bottomleft location=outside outerpad=(top=0 left=0 right=0 bottom=0);
keylegend "pandemic" / valueattrs=(size=12) noborder position=bottomleft location=outside outerpad=(top=0 left=0 right=0 bottom=10);
keylegend "interval" / valueattrs=(size=12) noborder position=bottomleft location=outside outerpad=(top=0 left=0 right=0 bottom=10);
run;
ods layout end;
title;

*By Cause;
ods powerpoint startpage=now;
title height=14pt "&statename.";
title2 height=12pt "Observed and Predicted Deaths/Day/100,000 Population by Cause";
ods graphics / noborder width=2.25in height=1.5in;
ods layout gridded columns=4 rows=4 column_widths=(2.25in 2.25in 2.25in 2.25in) column_gutter=0.05in y=0.15in;

ods region column=1 row=1; %plot(state=&state., cod=All Causes, name=All Causes, xlabel=display=(nolabel novalues),ylabel=label="Deaths/Day/100,000");
ods region column=2 row=1; %plot(state=&state., cod=Cardiovascular Disease, name=Cardiovascular Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=3 row=1; %plot(state=&state., cod=Cancer, name=Cancer, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));

ods region column=4 row=1; data plot; set merged; where year=2020 and state="&state." and cod=0; deaths_st=deaths/days/popest*100000; run;
title "COVID-19"; proc sgplot data=plot noborder noautolegend; styleattrs axisextent=data;
series x=month y=deaths_st / lineattrs=(color=black thickness=2);
xaxis display=(nolabel novalues) values=(1 to 12 by 1); yaxis display=(nolabel); run;

ods region column=1 row=2; %plot(state=&state., cod=CLRD, name=CLRD, xlabel=display=(nolabel novalues),ylabel=label="Deaths/Day/100,000");
ods region column=2 row=2; %plot(state=&state., cod=Alzheimers Disease, name=Alzheimers Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=3 row=2; %plot(state=&state., cod=Diabetes, name=Diabetes, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=4 row=2; %plot(state=&state., cod=Influenza and Pneumonia, name=Influenza and Pneumonia, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));

ods region column=1 row=3; %plot(state=&state., cod=Kidney Disease, name=Kidney Disease, xlabel=display=(nolabel novalues),ylabel=label="Deaths/Day/100,000");
ods region column=2 row=3; %plot(state=&state., cod=Liver Disease, name=Liver Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=3 row=3; %plot(state=&state., cod=HIV, name=HIV, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=4 row=3; %plot(state=&state., cod=Unknown Disease, name=Unknown Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));

ods region column=1 row=4; %plot(state=&state., cod=Suicide, name=Suicide, xlabel=label="Month",ylabel=label="Deaths/Day/100,000");
ods region column=2 row=4; %plot(state=&state., cod=Motor Vehicle Accidents, name=Motor Vehicle Accidents, xlabel=label="Month",ylabel=display=(nolabel));
ods region column=3 row=4; %plot(state=&state., cod=Homicide, name=Homicide, xlabel=label="Month",ylabel=display=(nolabel));
ods region column=4 row=4; %plot(state=&state., cod=Injury of Undetermined Intent, name=Injury of Undetermined Intent, xlabel=label="Month",ylabel=display=(nolabel));

ods layout end;
title;
%mend;

%loop(state=US, statename=United States);
%loop(state=R1, statename=Mideast + New England);
%loop(state=R2, statename=Southeast + Southwest);
%loop(state=R3, statename=Far West + Plains + Rocky Mountain);
%loop(state=R4, statename=Great Lakes);
%loop(state=AL, statename=Alabama);
%loop(state=AK, statename=Alaska);
%loop(state=AZ, statename=Arizona);
%loop(state=AR, statename=Arkansas);
%loop(state=CA, statename=California);
%loop(state=CO, statename=Colorado);
%loop(state=CT, statename=Connecticut);
%loop(state=DE, statename=Delaware);
%loop(state=DC, statename=District of Columbia);
%loop(state=FL, statename=Florida);
%loop(state=GA, statename=Georgia);
%loop(state=HI, statename=Hawaii);
%loop(state=ID, statename=Idaho);
%loop(state=IL, statename=Illinois);
%loop(state=IN, statename=Indiana);
%loop(state=IA, statename=Iowa);
%loop(state=KS, statename=Kansas);
%loop(state=KY, statename=Kentucky);
%loop(state=LA, statename=Louisiana);
%loop(state=ME, statename=Maine);
%loop(state=MD, statename=Maryland);
%loop(state=MA, statename=Massachusetts);
%loop(state=MI, statename=Michigan);
%loop(state=MN, statename=Minnesota);
%loop(state=MS, statename=Mississippi);
%loop(state=MO, statename=Missouri);
%loop(state=MT, statename=Montana);
%loop(state=NE, statename=Nebraska);
%loop(state=NV, statename=Nevada);
%loop(state=NH, statename=New Hampshire);
%loop(state=NJ, statename=New Jersey);
%loop(state=NM, statename=New Mexico);
%loop(state=NY, statename=New York);
%loop(state=NC, statename=North Carolina);
%loop(state=ND, statename=North Dakota);
%loop(state=OH, statename=Ohio);
%loop(state=OK, statename=Oklahoma);
%loop(state=OR, statename=Oregon);
%loop(state=PA, statename=Pennsylvania);
%loop(state=RI, statename=Rhode Island);
%loop(state=SC, statename=South Carolina);
%loop(state=SD, statename=South Dakota);
%loop(state=TN, statename=Tennessee);
%loop(state=TX, statename=Texas);
%loop(state=UT, statename=Utah);
%loop(state=VT, statename=Vermont);
%loop(state=VA, statename=Virginia);
%loop(state=WA, statename=Washington);
%loop(state=WV, statename=West Virginia);
%loop(state=WI, statename=Wisconsin);
%loop(state=WY, statename=Wyoming);

ods powerpoint close;
ods html;

*Plot excess deaths;
data excess (keep=year month state statename cod excess excess_lower excess_upper);
set expected;
where year=2020;
excess_lower=deaths-expected_upper;
excess_upper=deaths-expected_lower;
run;

%macro plot(state=,cod=,name=,xlabel=,ylabel=);
data plot; set excess; where state="&state" and cod="&cod."; run;
title "&name.";
proc sgplot data=plot noborder noautolegend;
styleattrs axisextent=data;
series x=month y=excess / lineattrs=(color=cx2a4858 pattern=solid);
band x=month lower=excess_lower upper=excess_upper / fillattrs=(color=cx2a4858 transparency=0.9);
refline 0 / axis=y lineattrs=(color=black pattern=dash);
xaxis &xlabel. values=(1 to 12 by 1);
yaxis &ylabel.;
run;
%mend;

title;
ods html close;
options nodate nonumber orientation=landscape;
ods powerpoint file="&source.\ExcessDeathsByCOD.pptx" style=mystyle startpage=no;

%macro loop(state=, statename=);
ods powerpoint startpage=now;
title height=14pt "&statename.";
title2 height=12pt "Excess Deaths by Cause of Death";
ods graphics / noborder width=2.25in height=1.5in;
ods layout gridded columns=4 rows=4 column_widths=(2.25in 2.25in 2.25in 2.25in) column_gutter=0.05in y=0.15in;

ods region column=1 row=1; %plot(state=&state., cod=All Causes, name=All Causes, xlabel=display=(nolabel novalues),ylabel=label="# Excess Deaths");
ods region column=2 row=1; %plot(state=&state., cod=Cardiovascular Disease, name=Cardiovascular Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=3 row=1; %plot(state=&state., cod=Cancer, name=Cancer, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));

ods region column=4 row=1; data plot; set merged; where year=2020 and state="&state." and cod=0; run;
title "COVID-19"; proc sgplot data=plot noborder noautolegend; styleattrs axisextent=data;
series x=month y=deaths / lineattrs=(color=cx2a4858 pattern=solid);
xaxis display=(nolabel novalues) values=(1 to 12 by 1); yaxis display=(nolabel); run;

ods region column=1 row=2; %plot(state=&state., cod=CLRD, name=CLRD, xlabel=display=(nolabel novalues),ylabel=label="# Excess Deaths");
ods region column=2 row=2; %plot(state=&state., cod=Alzheimers Disease, name=Alzheimers Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=3 row=2; %plot(state=&state., cod=Diabetes, name=Diabetes, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=4 row=2; %plot(state=&state., cod=Influenza and Pneumonia, name=Influenza and Pneumonia, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));

ods region column=1 row=3; %plot(state=&state., cod=Kidney Disease, name=Kidney Disease, xlabel=display=(nolabel novalues),ylabel=label="# Excess Deaths");
ods region column=2 row=3; %plot(state=&state., cod=Liver Disease, name=Liver Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=3 row=3; %plot(state=&state., cod=HIV, name=HIV, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=4 row=3; %plot(state=&state., cod=Unknown Disease, name=Unknown Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));

ods region column=1 row=4; %plot(state=&state., cod=Suicide, name=Suicide, xlabel=label="Month",ylabel=label="# Excess Deaths");
ods region column=2 row=4; %plot(state=&state., cod=Motor Vehicle Accidents, name=Motor Vehicle Accidents, xlabel=label="Month",ylabel=display=(nolabel));
ods region column=3 row=4; %plot(state=&state., cod=Homicide, name=Homicide, xlabel=label="Month",ylabel=display=(nolabel));
ods region column=4 row=4; %plot(state=&state., cod=Injury of Undetermined Intent, name=Injury of Undetermined Intent, xlabel=label="Month",ylabel=display=(nolabel));

ods layout end;
title;
%mend;

%loop(state=US, statename=United States);
%loop(state=R1, statename=Mideast + New England);
%loop(state=R2, statename=Southeast + Southwest);
%loop(state=R3, statename=Far West + Plains + Rocky Mountain);
%loop(state=R4, statename=Great Lakes);
%loop(state=AL, statename=Alabama);
%loop(state=AK, statename=Alaska);
%loop(state=AZ, statename=Arizona);
%loop(state=AR, statename=Arkansas);
%loop(state=CA, statename=California);
%loop(state=CO, statename=Colorado);
%loop(state=CT, statename=Connecticut);
%loop(state=DE, statename=Delaware);
%loop(state=DC, statename=District of Columbia);
%loop(state=FL, statename=Florida);
%loop(state=GA, statename=Georgia);
%loop(state=HI, statename=Hawaii);
%loop(state=ID, statename=Idaho);
%loop(state=IL, statename=Illinois);
%loop(state=IN, statename=Indiana);
%loop(state=IA, statename=Iowa);
%loop(state=KS, statename=Kansas);
%loop(state=KY, statename=Kentucky);
%loop(state=LA, statename=Louisiana);
%loop(state=ME, statename=Maine);
%loop(state=MD, statename=Maryland);
%loop(state=MA, statename=Massachusetts);
%loop(state=MI, statename=Michigan);
%loop(state=MN, statename=Minnesota);
%loop(state=MS, statename=Mississippi);
%loop(state=MO, statename=Missouri);
%loop(state=MT, statename=Montana);
%loop(state=NE, statename=Nebraska);
%loop(state=NV, statename=Nevada);
%loop(state=NH, statename=New Hampshire);
%loop(state=NJ, statename=New Jersey);
%loop(state=NM, statename=New Mexico);
%loop(state=NY, statename=New York);
%loop(state=NC, statename=North Carolina);
%loop(state=ND, statename=North Dakota);
%loop(state=OH, statename=Ohio);
%loop(state=OK, statename=Oklahoma);
%loop(state=OR, statename=Oregon);
%loop(state=PA, statename=Pennsylvania);
%loop(state=RI, statename=Rhode Island);
%loop(state=SC, statename=South Carolina);
%loop(state=SD, statename=South Dakota);
%loop(state=TN, statename=Tennessee);
%loop(state=TX, statename=Texas);
%loop(state=UT, statename=Utah);
%loop(state=VT, statename=Vermont);
%loop(state=VA, statename=Virginia);
%loop(state=WA, statename=Washington);
%loop(state=WV, statename=West Virginia);
%loop(state=WI, statename=Wisconsin);
%loop(state=WY, statename=Wyoming);

ods powerpoint close;
ods html;


***TABLES***;
*Get total observed, expected and excess deaths from March-December 2020;
proc sort data=expected; by state cod; run;
data summary (keep=state cod cum_observed cum_expected cum_excess cum_excess_lower cum_excess_upper increase);
set expected;
where year=2020 and month=12;
increase=(cum_observed-cum_expected)/cum_expected;
run;

*Merge in observed deaths from COVID-19;
proc sort data=counts; by state; run;
ods exclude all;
proc means data=counts sum; by state; var deaths; where cod=0 and year=2020 and month in(3:12); output out=covid sum(deaths)=cum_observed; run;
ods exclude none;
data covid; length cod $33.; set covid; cod="COVID-19"; drop _TYPE_ _FREQ_; run;
data summary; set summary covid; run;
proc sort data=summary; by state cod; run;

*Calculate rates using population estimate from January 2020;
data popestjan (drop=statename year month); set popest; where year=2020 and month=1; run;
data summary (drop=popest); merge summary popestjan; by state;
rate=(cum_excess/popest)*100000;
run;

*Merge in correlation coefficients;
proc sort data=summary; by state cod; run; proc sort data=corr; by state cod; run;
data summary; merge summary corr; by state cod; format cum_observed cum_expected cum_excess comma16.0 increase percentn8.1 rate 8.1 corr 8.2; run;
proc print data=summary; run;

*Export;
proc export data=summary outfile="&source.\summary.csv" dbms=csv replace; run;

*Tables 1 & 2;
data tables (keep=n state cod cum_observed cum_expected excess_pi increase rate corr);
set summary;
if cod ne "COVID-19" then excess_pi=cat(trim(left(put(round(cum_excess,1),comma16.0)))," (",trim(left(put(round(cum_excess_lower,1),comma16.0))),", ", trim(left(put(round(cum_excess_upper,1),comma16.0))),")"); else excess_pi="";
*order rows in order of observed prevalence, within internal vs. external causes;
if cod="Cardiovascular Disease" then n=1;
if cod="Cancer" then n=2;
if cod="COVID-19" then n=3;
if cod="CLRD" then n=4;
if cod="Alzheimers Disease" then n=5;
if cod="Diabetes" then n=6;
if cod="Liver Disease" then n=7;
if cod="Kidney Disease" then n=8;
if cod="Influenza and Pneumonia" then n=9;
if cod="Unknown Disease" then n=10;
if cod="HIV" then n=11;
if cod="Other Internal Causes" then n=12;
if cod="Suicide" then n=13;
if cod="Motor Vehicle Accidents" then n=14;
if cod="Homicide" then n=15;
if cod="Injury of Undetermined Intent" then n=16;
if cod="Other External Causes" then n=17;
if cod="All Causes" then n=18;
run;
proc sort data=tables; by state n; run;
*order columns;
data table1 (drop=n state); retain cod cum_observed cum_expected excess_pi increase rate corr; set tables; where state="US"; run;
data table2 (drop=n increase rate corr); retain state cod cum_observed cum_expected excess_pi; set tables; where state in("R1","R2","R3","R4"); run;
*Export;
proc export data=table1 outfile="&source.\table1.csv" dbms=csv replace; run;
proc export data=table2 outfile="&source.\table2.csv" dbms=csv replace; run;


***COMPARISON ACROSS REGIONS***;
proc import datafile="&source.\excess_mortality_estimates_agest.csv" out=expected_agest replace; guessingrows=190000; run;
proc print data=expected_agest; where state="US" and year=2020 and cod="All Causes"; run;

*Forest plot of cumulative age-standardized rate of excess deaths per 100,000 standard population, with 95% PI;
data expected_agest (keep=state statename cod cum_excess2 cum_excess_lower cum_excess_upper rename=(cum_excess2=cum_excess));
set expected_agest;
where year=2020 and month=12;
*Convert character variables to numeric;
if cum_excess="NA" then cum_excess=""; cum_excess2=input(cum_excess, 8.);
run;
*Sort in order of # excess deaths;
proc sort data=expected_agest; by cum_excess; run;
data plot;
set expected_agest; where state in("R1","R2","R3","R4") and cod notin("All Causes","COVID","Other Internal Causes","Other External Causes");
rank=_n_;
ratePI=cat(round(cum_excess,0.1)," (", round(cum_excess_lower,0.1),", ", round(cum_excess_upper,0.1),")");
stat1="Rate (95% PI)";
null=.;
if cum_excess<0 then lowerlabel=cum_excess_lower; else lowerlabel=.;
if cum_excess>0 then upperlabel=cum_excess_upper; else upperlabel=.;
run;
*Assign cause of death as format for rank variable;
data rankfmt (keep=fmtname start end label); set plot; fmtname="rankfmt"; start=rank; end=rank; label=cod; run;
proc format library=work cntlin=rankfmt; run;

proc template;
 define style styles.mystyle;
      parent = styles.htmlBlue;
      style GraphFonts  from GraphFonts /                                                                
         'GraphDataFont' = ("<sans-serif>, <MTsans-serif>",7pt)                                 
         'GraphValueFont' = ("<sans-serif>, <MTsans-serif>",7pt);
 end;
run;

*colorblind-friendly color palette: color-hex.com/color-palette/49436;
data attrmap;
length id value markercolor linecolor textcolor markersymbol $35;
  id='statename'; value='Mideast and New England'; markercolor='CXCC79A7'; linecolor='CXCC79A7'; textcolor='CXCC79A7'; markersymbol='circlefilled'; output;
  id='statename'; value='Southeast and Southwest'; markercolor='CXD55E00'; linecolor='CXD55E00'; textcolor='CXD55E00'; markersymbol='diamondfilled'; output;
  id='statename'; value='Far West, Plains and Rocky Mountain'; markercolor='CX009E73'; linecolor='CX009E73'; textcolor='CX009E73'; markersymbol='squarefilled'; output;
  id='statename'; value='Great Lakes'; markercolor='CX0072B2'; linecolor='CX0072B2'; textcolor='CX0072B2'; markersymbol='trianglefilled'; output;
run;

ods html close;
ods graphics / reset width=8.5in height=10in imagename="forestplot";
ods listing sge=off style=mystyle image_dpi=300;

proc sgplot data=plot noautolegend nocycleattrs dattrmap=attrmap;
*Forest Plot;
scatter y=rank x=cum_excess / group=statename attrid=statename name="ptest";
highlow y=rank low=cum_excess_lower high=cum_excess_upper / type=line group=statename attrid=statename lineattrs=(pattern=solid);
scatter y=rank x=upperlabel / group=statename attrid=statename markerattrs=(size=0) datalabel=ratePI datalabelpos=right;
scatter y=rank x=lowerlabel / group=statename attrid=statename markerattrs=(size=0) datalabel=ratePI datalabelpos=left;

refline 0 / axis=x;

xaxis offsetmin=0 offsetmax=0 values=(-5 0 5 10 15 20 25 30) valueshint min=-20 max=55 label="Excess Deaths per 100,000 Standard Population" labelattrs=(size=8);
yaxis display=(nolabel noticks) values=(1 to 56 by 1) offsetmin=0.02 offsetmax=0.02;

keylegend "ptest" / noborder position=bottom location=outside down=2;

format rank rankfmt.;
run;

ods listing close;
ods html;



***ASSESSMENT OF MODEL FIT***;
*Predict excess deaths for March-December 2019 (in R);
proc import datafile="&source.\model_fit.csv" out=expected replace; guessingrows=190000; run;
data expected (drop=expected_st expected_st_lower expected_st_upper rename=(expected_st2=expected_st expected_st_lower2=expected_st_lower expected_st_upper2=expected_st_upper));
set expected (keep=year month state statename cod deaths_st expected_st expected_st_lower expected_st_upper);
where year=2019;
if month>2 then do; expected_st2=input(expected_st, 8.); expected_st_lower2=input(expected_st_lower, 8.); expected_st_upper2=input(expected_st_upper, 8.); end;
run;

*Plot observed (March-December 2019) and predicted (March-December 2019) deaths/day/100,000 by underlying COD;
proc template;
define style styles.mystyle;
	parent = styles.journal;
	class SystemTitle / fontfamily="Arial" fontsize=12pt fontstyle=roman fontweight=medium;
	class SystemFooter / fontfamily="Arial" fontsize=10pt fontstyle=roman fontweight=medium;
	end;
run;

%macro plot(state=,cod=,name=,xlabel=,ylabel=);
data plot; set expected; where state="&state" and cod="&cod."; run;
title "&name.";
proc sgplot data=plot noborder noautolegend;
styleattrs axisextent=data axisbreak=bracket
datacontrastcolors=(cxfafa6e cxd9f271 cxb9e976 cx9cdf7c cx7fd482 cx64c987 cx4abd8c cx30b08e cx14a38f cx00968e cx00898a cx007b84 cx106e7c cx1d6172 cx265466 cx2a4858);
*colors: https://colordesigner.io/gradient-generator;
scatter x=month y=deaths_st;
series x=month y=expected_st / lineattrs=(color=red pattern=solid thickness=2);
band x=month lower=expected_st_lower upper=expected_st_upper / fillattrs=(color=red transparency=0.9);
xaxis &xlabel. values=(1 to 12 by 1);
yaxis &ylabel.;
run;
%mend;

title;
ods html close;
options nodate nonumber orientation=landscape;
ods powerpoint file="&source.\ModelFit.pptx" style=mystyle startpage=no;

%macro loop(state=, statename=);
*All Causes;
data plot; set expected; where state="&state." and cod="All Causes"; run;
ods powerpoint startpage=now;
title height=14pt "&statename.";
title2 height=12pt "Observed and Predicted Deaths/Day/100,000 Population from All Causes, March-December 2019";
ods graphics / noborder width=12in height=8in maxlegendarea=100;
ods layout gridded columns=1 rows=1 y=0.25in;
ods region;
proc sgplot data=plot noborder noautolegend;
title;
styleattrs axisextent=data axisbreak=bracket;
scatter x=month y=deaths_st / name="observed";
series x=month y=expected_st / name="predicted" lineattrs=(color=red pattern=solid thickness=2);
band x=month lower=expected_st_lower upper=expected_st_upper / fillattrs=(color=red transparency=0.9);
legenditem type=fill name="interval" / label="95% Prediction Interval" fillattrs=(color=red transparency=0.9);
xaxis label="Month" values=(1 to 12 by 1);
yaxis label="Deaths per Day per 100,000 Population";
label expected_st="Predicted";
label deaths_st="Observed";
keylegend "observed" / down=2 valueattrs=(size=12) noborder position=bottomleft location=outside outerpad=(top=10 left=0 right=0 bottom=0);
keylegend "predicted" / valueattrs=(size=12) noborder position=bottomleft location=outside outerpad=(top=0 left=0 right=0 bottom=0);
keylegend "interval" / valueattrs=(size=12) noborder position=bottomleft location=outside outerpad=(top=0 left=0 right=0 bottom=0);
run;
ods layout end;
title;

ods powerpoint startpage=now;
title height=14pt "&statename.";
title2 height=12pt "Observed and Predicted Deaths/Day/100,000 Population by Cause, March-December 2019";
ods graphics / noborder width=2.25in height=1.5in;
ods layout gridded columns=4 rows=4 column_widths=(2.25in 2.25in 2.25in 2.25in) column_gutter=0.05in y=0.15in;

ods region column=1 row=1; %plot(state=&state., cod=All Causes, name=All Causes, xlabel=display=(nolabel novalues),ylabel=label="Deaths/Day/100,000");
ods region column=2 row=1; %plot(state=&state., cod=Cardiovascular Disease, name=Cardiovascular Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=3 row=1; %plot(state=&state., cod=Cancer, name=Cancer, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));

ods region column=1 row=2; %plot(state=&state., cod=CLRD, name=CLRD, xlabel=display=(nolabel novalues),ylabel=label="Deaths/Day/100,000");
ods region column=2 row=2; %plot(state=&state., cod=Alzheimers Disease, name=Alzheimers Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=3 row=2; %plot(state=&state., cod=Diabetes, name=Diabetes, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=4 row=2; %plot(state=&state., cod=Influenza and Pneumonia, name=Influenza and Pneumonia, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));

ods region column=1 row=3; %plot(state=&state., cod=Kidney Disease, name=Kidney Disease, xlabel=display=(nolabel novalues),ylabel=label="Deaths/Day/100,000");
ods region column=2 row=3; %plot(state=&state., cod=Liver Disease, name=Liver Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=3 row=3; %plot(state=&state., cod=HIV, name=HIV, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));
ods region column=4 row=3; %plot(state=&state., cod=Unknown Disease, name=Unknown Disease, xlabel=display=(nolabel novalues),ylabel=display=(nolabel));

ods region column=1 row=4; %plot(state=&state., cod=Suicide, name=Suicide, xlabel=label="Month",ylabel=label="Deaths/Day/100,000");
ods region column=2 row=4; %plot(state=&state., cod=Motor Vehicle Accidents, name=Motor Vehicle Accidents, xlabel=label="Month",ylabel=display=(nolabel));
ods region column=3 row=4; %plot(state=&state., cod=Homicide, name=Homicide, xlabel=label="Month",ylabel=display=(nolabel));
ods region column=4 row=4; %plot(state=&state., cod=Injury of Undetermined Intent, name=Injury of Undetermined Intent, xlabel=label="Month",ylabel=display=(nolabel));

ods layout end;
title;
%mend;

%loop(state=R1, statename=Mideast + New England);
%loop(state=R2, statename=Southeast + Southwest);
%loop(state=R3, statename=Far West + Plains + Rocky Mountain);
%loop(state=R4, statename=Great Lakes);


ods powerpoint close;
ods html;
