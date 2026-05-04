#!/usr/bin/env python3

import os
import glob
import argparse
import numpy as np
import xarray as xr

def oxy_gain_correction(mission, start_gain=1.0, end_gain=1.0):
    """Function for post-processing of Seaglider data."""

    # Extract glider ID from directory structure and find all dive files
    # data_dir = f'/home/server/pi/homes/marqjace/grg/seaglider-raw/{mission}/real-time'
    data_dir = f'C:/Users/marqjace/data/seaglider/sg686/{mission}'

    files = [f for f in os.listdir(data_dir) if f.endswith(".nc")]
    if not files:
        raise ValueError("No .nc files found")

    # glider_id = files[0][1:4]
    glider_id = "686"

    dive_files = sorted(glob.glob(os.path.join(data_dir, f"p{glider_id}*.nc")))    ### Change to f"p{glider_id}*.nc" for actual file. 

    print(f"Found {len(dive_files)} files")
    print(f"glider_id: {glider_id}")
    print(f"Searching in: {data_dir}")

    # ---------------------------------------------------------
    # Build interpolated gains using actual timestamps
    # ---------------------------------------------------------

    times = []

    for f in dive_files:
        try:
            with xr.open_dataset(
                f,
                drop_variables=['compass_timeouts_times_truck'],
                decode_timedelta=False
            ) as ds:

                # first timestamp in file
                t = ds['time'].values[0]
                times.append(t)

        except Exception as e:
            print(f"Could not read time from {f}: {e}")
            times.append(np.nan)

    # convert datetime64 -> float seconds
    times = np.array(times).astype('datetime64[s]').astype(float)

    # interpolate gains across mission duration
    gains = np.interp(
        times,
        [times[0], times[-1]],
        [start_gain, end_gain]
    )

    # ---------------------------------------------------------

    # processed_dir = f'/home/server/pi/homes/marqjace/grg/seaglider-proc/{mission}/real-time'
    processed_dir = f'C:/Users/marqjace/data/seaglider/sg686/{mission}/processed'

    os.makedirs(processed_dir, exist_ok=True)

    # Apply interpolated gain file-by-file
    for f, gain in zip(dive_files, gains):

        print(f'Processing file {f} with gain {gain:.4f} ...')

        try:
            with xr.open_dataset(
                f,
                drop_variables=['compass_timeouts_times_truck'],
                decode_timedelta=False
            ) as ds:

                oxy = ds['aanderaa4831_dissolved_oxygen'].values

                oxy_calibrated = oxy * gain

                ds_corrected = ds.copy()

                ds_corrected['aanderaa4831_dissolved_oxygen_adjusted'] = (
                    ('aa4831_data_point'),
                    oxy_calibrated
                )

                var = ds_corrected['aanderaa4831_dissolved_oxygen_adjusted']

                var.attrs['standard_name'] = (
                    'mole_concentration_of_dissolved_molecular_oxygen_in_sea_water'
                )
                var.attrs['units'] = 'µmol/kg'
                var.attrs['gain'] = float(gain)

                var.attrs['comment'] = (
                    'Dissolved oxygen concentration corrected with '
                    'time-interpolated sensor gain.'
                )

                var.attrs['platform'] = 'glider'
                var.attrs['instrument'] = 'aa4831'

                output_file = os.path.join(
                    processed_dir,
                    os.path.basename(f)
                )

                ds_corrected.to_netcdf(output_file)

                print(f"Saved corrected data to {output_file}")

        except Exception as e:
            print(f"Error processing file {f}: {e}")
            continue


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Apply oxygen gain correction to Seaglider data."
    )

    parser.add_argument(
        "mission",
        type=str,
        help="Mission name (e.g., '20260314_sg266')"
    )

    parser.add_argument(
        "--start_gain",
        type=float,
        required=True,
        help="Gain at start of mission"
    )

    parser.add_argument(
        "--end_gain",
        type=float,
        required=True,
        help="Gain at end of mission"
    )

    args = parser.parse_args()

    oxy_gain_correction(
        args.mission,
        args.start_gain,
        args.end_gain
    )