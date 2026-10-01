/*****************************************************************************
 * Flight Price Analytics - SAS (SAS University Edition / SAS Studio)
 * Author: Jeremiah Dibie
 *
 * Dataset: Kaggle "Flight Price Prediction" (EaseMyTrip, ~300,000 rows)
 *   https://www.kaggle.com/datasets/shubhambathwal/flight-price-prediction
 * Download Clean_Dataset.csv and set &path below to the folder containing it.
 *****************************************************************************/

%let path = /home/your_sas_user/flight-price-analytics;

/* Create a Project Library */
libname project "&path";
run;

/* Import the flight CSV file */
proc import datafile="&path/Clean_Dataset.csv"
            out=project.flight
            dbms=csv
            replace;
   getnames=yes;
run;

/* Print the content of the data */
proc contents data=project.flight;
run;

/* Print the first 20 observations of the data */
proc print data=project.flight (obs=20) noobs;
run;


/* ---------------------------------------------------------------------------
 * Data preparation
 * ------------------------------------------------------------------------- */

/* Drop rows with missing values for all variables */
data project.flight;
   set project.flight;
   if not cmiss(of _all_);
run;

/* Summary statistics for numeric variables */
proc means data=project.flight;
   var duration days_left price;
run;

/* Convert duration to minutes (rename duration to duration_hour) */
data project.flight;
   set project.flight(rename=(duration=duration_hour));
   duration_minutes = duration_hour*60;
run;

proc print data=project.flight (obs=20);
run;

/* Convert price from Indian rupees to US dollars (1 INR = 0.012 USD, 29/04/2024) */
data project.flight;
   set project.flight(rename=(price=Price_Indian_Rupee));
   Price_US_dollars = Price_Indian_Rupee*0.012;
run;

/* Summary statistics for numeric variables */
proc means data=project.flight;
   var duration_hour days_left Price_US_dollars;
run;

proc print data=project.flight (obs=20);
   format Price_US_dollars dollar10.2;
run;


/* ---------------------------------------------------------------------------
 * Exploratory data analysis
 * ------------------------------------------------------------------------- */

/* Calculate frequency of airline */
proc freq data=project.flight noprint;
   tables airline / out=airline_freq (rename=(count=Freq));
run;

/* Bar plot of tickets sold by different airlines */
proc sgplot data=airline_freq;
   vbar airline /
      response=Freq
      datalabel
      nostatlabel;
   title 'Tickets Sold by Different Airlines';
   xaxis label='Airlines';
   yaxis label='Number of Tickets';
run;

/* Impact of buying tickets before departure:
   average price and days left by airline */
proc means data=project.flight noprint;
   class airline;
   var Price_US_dollars days_left;
   output out=avg_airline(drop=_type_ _freq_)
          mean(Price_US_dollars)=avg_price mean(days_left)=avg_days_left;
run;

/* Bar plot of average price by airline */
proc sgplot data=avg_airline;
   vbar airline / response=avg_price
                  group=airline
                  datalabel
                  nostatlabel;
   format avg_price dollar12.2;
   title 'Average Price by Airlines in USD';
   xaxis label='Airline';
   yaxis label='Average Price';
run;

/* Average price by departure time and arrival time */
proc sgplot data=project.flight;
   vbar departure_time / response=Price_US_dollars stat=mean datalabel;
   xaxis label='Departure Time' fitpolicy=rotate;
   yaxis label='Price in USD';
   format Price_US_dollars dollar12.;
   title 'Average Price in USD by Departure Time';
run;

proc sgplot data=project.flight;
   vbar arrival_time / response=Price_US_dollars stat=mean datalabel;
   xaxis label='Arrival Time' fitpolicy=rotate;
   yaxis label='Price in USD';
   format Price_US_dollars dollar12.;
   title 'Average Price in USD by Arrival Time';
run;

/* KDE plots for price distribution by departure time */
proc sgpanel data=project.flight;
   panelby departure_time / layout=rowlattice columns=1 novarname;
   density Price_US_dollars / group=arrival_time;
   colaxis label='Price';
   rowaxis label='Density';
   format Price_US_dollars dollar12.;
   title 'Price Distribution by Departure Time';
run;

/* KDE plots for price distribution by arrival time */
proc sgpanel data=project.flight;
   panelby arrival_time / layout=rowlattice columns=1 novarname;
   density Price_US_dollars / group=departure_time;
   colaxis label='Price';
   rowaxis label='Density';
   format Price_US_dollars dollar12.;
   title 'Price Distribution by Arrival Time';
run;

/* Donut chart for share of class */
ods graphics / reset width=7in height=4.5in;
title 'Flight Class Distribution';
proc sgpie data=project.flight;
   styleattrs datacolors=(gold olive);
   donut class / holevalue holelabel='Count' ringsize=0.5;
run;

/* KDE plot for price distribution by class */
proc sgpanel data=project.flight;
   panelby class / novarname columns=1;
   density Price_US_dollars / group=class;
   colaxis label='Price';
   rowaxis label='Density';
   format Price_US_dollars dollar12.;
   title 'Price Distribution by Class';
run;

/* Bar plot for number of stops vs. price */
proc sgplot data=project.flight;
   vbar stops / response=Price_US_dollars stat=mean group=class datalabel;
   xaxis label='Number of Stops';
   yaxis label='Price';
   format Price_US_dollars dollar12.;
   title 'Average Price by Number of Stops for both Business and Economy Class';
run;


/* ---------------------------------------------------------------------------
 * Predicting flight prices with linear regression
 * ------------------------------------------------------------------------- */

/* Encode the categorical values */
data predictors;
   set project.flight;
   if class = 'Economy' then class_num = 0;
   else if class = 'Business' then class_num = 1;
   if airline = 'Indigo' then airline_num = 1;
   else if airline = 'Air_India' then airline_num = 2;
   else if airline = 'GO_FIRST' then airline_num = 3;
   else if airline = 'SpiceJet' then airline_num = 4;
   else if airline = 'Vistara' then airline_num = 5;
   else if airline = 'AirAsia' then airline_num = 6;
   if stops = 'zero' then stops_num = 0;
   else if stops = 'one' then stops_num = 1;
   else if stops in ('two', 'two_or_more') then stops_num = 2;
run;

/* Fit linear regression model with the chosen predictors */
proc reg data=predictors;
   model Price_US_dollars = airline_num class_num stops_num duration_minutes;
   title 'Linear Regression Model to Predict Price';
   output out=prediction_predicted predicted=predicted;
run;

/* Print predicted data */
proc print data=prediction_predicted (obs=20);
run;

/* Compute model performance metrics */
proc reg data=prediction_predicted;
   model Price_US_dollars = predicted;
   output out=prediction_metrics p=predicted_resid r=r;
run;

/* Print model performance metrics */
proc print data=prediction_metrics(obs=20);
   var Price_US_dollars predicted predicted_resid r;
run;
