# ODROID-Process-Migration-Data
  
COLLECTING PROCESS DATA AND DETERMINING KEY PROCESSES:  
  
  
To collect data: sudo ./run-all.sh [prefix] [number of iterations] collect  
  
This will create the following files in process-monitoring/data:  
- $SITE-prefix-$CORE_CONFIG-$GOV_STR-$ID.csv for each site - this is a list of processes and their time usage  
- $SITE-prefix-$CORE_CONFIG-$GOV_STR-$ID.txt for each site - this is a list of timestamps for the process  
  
This data can be analyzed using process-monitoring/graphing.R.  
I did this with R because it seemed like it was easier to interact with the the graphs this way. I recommend using RStudio (it's free).  
This R script lets you have a couple different views of the process data.  
There's a data set I already collected for this in process-monitoring/data/11-3-2019  
  
  
  
  
TESTING CORE CONFIGURATIONS:  
  
  
You might have to edit run.sh, run-all.sh, and plot.py, depending on what configurations you want to run  
  
To collect data: sudo ./run-all.sh [prefix] [number of iterations] configs  
This will create the following files:  
- json-data/prefix-$$CORE_CONFIG-$GOV_STR-$ID.json for each site and configuration - this is a list of timestamps for different events  
- powmon-data/prefix-$$CORE_CONFIG-$GOV_STR-$ID for each site and configuration - this list voltage and a bunch of other counters for each core  
  
To graph this data: python plot.py [prefix] [number of iterations]  
This will go through all of the files in the json-data and powmon-data with the given prefix to make graphs  
This will create the following files:  
- Scatterplots in the plots directory of power usage vs load time for each site. It gives both a version split up by loading phase and an overall one  
- plots/prefix-core-migration-data.csv - load time and energy data, formatted for analysis in Excel. The improvement-percentages.xlsx files in plots/11-27-19-400trials use this file  
- counters/prefix-counter-data.csv - counter data (i.e. cache refills), formatted for analysis in Excel. The counter-graphs.xlsx file in plots/11-27-19-400trials uses this file  
  
Examples of these files based on a run of 400 trials can be found in plots/11-27-19-400trials  
  