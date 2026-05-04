# Instructions for use

## sg_to_IOOS.py
- Currently run via a cron job and bash script in /grg.
  - Cron job runs every 15 minues and processes the latest gliderdac file produced by the basestation and linearly interpolates WL & DO data onto the CTD time grid. It also fixes naming conventions. 

## oxy_gain_correction_linear.py
- Lives in ```/grg/seaglider-proc/YYYYMMDD_sgXXX/software```.
  - Example to run: ```/home/server/hpc/grg/pixi_env/.pixi/envs/default/bin/python oxy_gain_correction_linear.py "20251111_sg686" --start_gain 1 --end_gain 1.0689```
  - Searches the given directory in ```seaglider-raw``` and applies a linear gain correction to '*aanderaa4831_dissolved_oxygen*' and saves the processed files in ```seaglider-proc```. The corrected oxygen data is named '*aanderaa4831_dissolved_oxygen_adjusted*'.

## glider_to_IOOS_seaglider.m/.py
- .m script from Fred Bahr @ MBARI for creating gliderdac compliant .nc files.
- .py script is a python version of the .m script.