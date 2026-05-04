import os
import glob
import argparse
import xarray as xr
# from pathlib import Path

def oxy_gain_correction(mission, gain=1.0):
    """Function for post-processing of Seaglider data.
    
    Args:
        mission (str): Mission name (e.g., '20260314_sg266').
        gain (float): Gain factor for oxygen correction.
    
    Returns:
        None
    """
    # Extract glider ID from directory structure and find all dive files
    data_dir = f'/home/server/pi/homes/marqjace/grg/seaglider-raw/{mission}/real-time'
    files = [f for f in os.listdir(data_dir) if f.endswith(".nc")]
    if not files:
        raise ValueError("No .nc files found")

    glider_id = files[0][1:4]  # "266" from p2660203.nc
    dive_files = sorted(glob.glob(os.path.join(data_dir, f"p{glider_id}*.nc")))
    print(f"Found {len(dive_files)} files")
    print(f"glider_id: {glider_id}")
    print(f"Searching in: {data_dir}")
    print(os.listdir(data_dir))
    print(f"Gain: {gain}")

    # Create directories if they doesn't exist
    mission = os.path.basename(os.path.dirname(data_dir))
    processed_dir = f'/home/server/pi/homes/marqjace/grg/seaglider-proc/{mission}/real-time'

    for f in dive_files:
        print(f'Processing file {f}....')
        try:
            with xr.open_dataset(f, drop_variables=['compass_timeouts_times_truck'], decode_timedelta=False) as ds:
                oxy = ds['aanderaa4831_dissolved_oxygen'].values
                oxy_calibrated = oxy * gain

                ds_corrected = ds.copy()
                ds_corrected['aanderaa4831_dissolved_oxygen_adjusted'] = (('aa4831_data_point'), oxy_calibrated)

                ds_corrected['aanderaa4831_dissolved_oxygen_adjusted'].attrs['standard_name'] = 'mole_concentration_of_dissolved_molecular_oxygen_in_sea_water'
                ds_corrected['aanderaa4831_dissolved_oxygen_adjusted'].attrs['units'] = 'µmol/kg'
                ds_corrected['aanderaa4831_dissolved_oxygen_adjusted'].attrs['gain'] = gain
                ds_corrected['aanderaa4831_dissolved_oxygen_adjusted'].attrs['comment'] = 'Dissolved oxygen concentration, calculated from optode tcphase corrected for salininty, depth, and sensor gain. Gain calculated using Winkler titration method.'
                ds_corrected['aanderaa4831_dissolved_oxygen_adjusted'].attrs['platform'] = 'glider'
                ds_corrected['aanderaa4831_dissolved_oxygen_adjusted'].attrs['instrument'] = 'aa4831'

                output_file = os.path.join(processed_dir, os.path.basename(f))
                ds_corrected.to_netcdf(output_file)
                print(f"Saved corrected data to {output_file}")

        except Exception as e:
            print(f"Error processing file {f}: {e}")
            continue

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Apply oxygen gain correction to Seaglider data.")
    parser.add_argument("mission", type=str, help="Mission name (e.g., '20260314_sg266')")
    parser.add_argument("--gain", type=float, default=1.0,
                            help="Gain factor for oxygen correction (default: 1.0)")

    args = parser.parse_args()

    oxy_gain_correction(args.mission, args.gain)