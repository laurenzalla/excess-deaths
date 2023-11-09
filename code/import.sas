*Read in NCHS Detailed Mortality Files - All Counties;

%let source=<filepath>;
libname data "&source.";

%macro import(geo=);
%do year=2005 %to 2020; *File format was consistent from 2005-2020;
data mort&geo.&year.;
infile "&source.\MortAC&year.\MULT&year..USPSAllCnty\MULT&year..&geo.AllCnty.txt";
input type 19 residence 20 @21 state_occ $2. @23 county_occ $3. @26 stateexp_occ $2. countypop_occ 28 @29 state_res $2. @33 staterec_res $2.
@35 county_res $3. @38 city_res $5. @43 citypop_res $1. @44 countymet_res $1. @45 stateexp_res $2. @55 state_birth $2. @59 staterec_birth $2.
edu1989 61-62 edu2003 63 eduflag 64 month 65-66 @69 sex $1. @70 age $4. ageflag 74 age52 75-76 age27 77-78 age12 79-80 age22 81-82 place 83
@84 marital $1. day 85 datayear 102-105 @106 work $1. manner 107 @108 burial $1. @109 autopsy $1. @110 certifier $1. @142 tobacco $1. pregnancy 143
activity 144 injury 145 @146 icd $4. icd358 150-152 icd113 154-156 icd130 157-159 icd39 160-161 entcond 163-164 @165 entcond1 $7. @172 entcond2 $7.
@179 entcond3 $7. @186 entcond4 $7. @193 entcond5 $7. @200 entcond6 $7. @207 entcond7 $7. @214 entcond8 $7. @221 entcond9 $7. @228 entcond10 $7.
@235 entcond11 $7. @242 entcond12 $7. @249 entcond13 $7. @256 entcond14 $7. @263 entcond15 $7. @270 entcond16 $7. @277 entcond17 $7. @284 entcond18 $7.
@291 entcond19 $7. @298 entcond20 $7. reccond 341-342 @344 reccond1 $5. @349 reccond2 $5. @354 reccond3 $5. @359 reccond4 $5. @364 reccond5 $5.
@369 reccond6 $5 @374 reccond7 $5. @379 reccond8 $5. @384 reccond9 $5. @389 reccond10 $5. @394 reccond11 $5. @399 reccond12 $5. @404 reccond13 $5.
@409 reccond14 $5. @414 reccond15 $5. @419 reccond16 $5. @424 reccond17 $5. @429 reccond18 $5. @434 reccond19 $5. @439 reccond20 $5. race 445-446
racebridged 447 raceimputed 448 race3 449 race5 450 hispanic 484-486 raceth 488 race40 489-490;
run;
%end;
%mend;

*All deaths occurring in the 50 U.S. States from 2005-2020;
	*Note: For 9 observations in 2006-2007, character values of 'N' for pregnancy are converted to missing (.); 
%import(geo=US);
*All deaths occurring in Puerto Rico, Guam, the U.S. Virgin Islands, American Samoa, and the Northern Mariana Islands from 2005-2020;
%import(geo=PS);

*This dataset contains one record per death that occurred in the U.S. from 2005-2020;
data data.mort0520;
set mortUS2005 mortUS2006 mortUS2007 mortUS2008 mortUS2009 mortUS2010 mortUS2011 mortUS2012 mortUS2013 mortUS2014 mortUS2015 mortUS2016 mortUS2017 mortUS2018 mortUS2019 mortUS2020
    mortPS2005 mortPS2006 mortPS2007 mortPS2008 mortPS2009 mortPS2010 mortPS2011 mortPS2012 mortPS2013 mortPS2014 mortPS2015 mortPS2016 mortPS2017 mortPS2018 mortPS2019 mortPS2020;
run;

