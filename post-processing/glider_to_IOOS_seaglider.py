# Program to take NetCDF files from OSU and reformat to IOOS for Seaglider
# code written by: jace.marquardt@oregonstate.edu
# adapted from code by: flbahr@mbari.org

import os
import glob
import numpy as np
import xarray as xr
# from datetime import datetime, timedelta
import argparse

def normalize_glider_id(glider_id):
    # Convert to string first
    gid = str(glider_id).strip().lower()

    # If it's numeric (e.g., 266 or 266.0)
    try:
        num = int(float(gid))
        return f"sg{num}", str(num)
    except ValueError:
        pass

    # If already like 'sg266'
    if gid.startswith("sg"):
        num = gid.replace("sg", "")
        return gid, num

    raise ValueError(f"Invalid glider_id: {glider_id}")

def interp_to_time(source_time, source_data, target_time):
        return np.interp(
            target_time.astype("float64"),
            source_time.astype("float64"),
            source_data,
            left=np.nan,
            right=np.nan
        )

def fill_nan(arr, fill_value=-1e34):
        arr = np.array(arr)
        arr[np.isnan(arr)] = fill_value
        return arr

def split_sg_profile(ds, threshold=0.07):
    """
    Splits seaglider dive data into ascent and descent phases.
    
    Parameters:
        ds (xr.Dataset): Dataset containing 'ctd_time' and 'ctd_depth' variables.
        
    Returns:
        dive (xr.Dataset): Dataset containing descent data.
        climb (xr.Dataset): Dataset containing ascent data.
    """

    ds = ds.sortby('ctd_time')

    # Convert ctd_time to numerical format (Unix epoch time in seconds)
    ds = ds.assign_coords(
        ctd_time=(ds["ctd_time"] - np.datetime64("1970-01-01T00:00:00")) / np.timedelta64(1, "s")
    )

    depth_diff = ds['ctd_depth'].differentiate('ctd_time')
    
    # Identify ascent and descent using the threshold
    dive = ds.where(depth_diff > threshold, drop=True)
    climb = ds.where(depth_diff < -threshold, drop=True)
    
    return dive, climb

def glider_to_IOOS_seaglider(glider_id, input_dir, deployment_name):

    """
    Parameters:
    -----------
    glider_id : str
        The ID of the glider
    input_dir : str
        The directory containing the input NetCDF files
    output_dir : str
        The directory where the output files will be saved
    deployment_name : str
        The name of the deployment

    Returns:
    --------
    None.
    """

    output_dir = os.path.join(input_dir, "gliderdac")

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Normalize glider_id
    g_id, num_id = normalize_glider_id(glider_id)
    
    if num_id == "266":
        wmo_id = "8901088"
    elif num_id == "646":
        wmo_id = ""
    elif num_id == "685":
        wmo_id = ""
    elif num_id == "686":
        wmo_id = ""
    else:
        raise ValueError(f"\nUnknown glider_id: {g_id}")

    print(f"\nGlider ID: {g_id}, WMO ID: {wmo_id}")

    # -----------------------------
    # Find files
    # -----------------------------
    files = sorted(glob.glob(os.path.join(input_dir, f"p{num_id}*.nc")))

    files = files[0:5] # Limit to first 5 files for testing

    print(f"\nFound {len(files)} files for glider {g_id}.")

    for file in files:
        
        filename = os.path.basename(file)
        print(f"Processing: {filename}")

        try:
            ds = xr.open_dataset(file, decode_timedelta=False)
        except Exception as e:
            print(f"\nError opening {file}: {e}")
            continue

        # Extract variables
        time = ds["ctd_time"].values
        depth = ds["ctd_depth"].values
        lat = ds["latitude"].values
        lon = ds["longitude"].values
        pressure = ds["ctd_pressure"].values
        temperature = ds["temperature"].values
        salinity = ds["salinity"].values
        conductivity = ds["conductivity"].values
        density = ds["density"].values

        temp_qc = ds["temperature_qc"].values
        salt_qc = ds["salinity_qc"].values
        cond_qc = ds["conductivity_qc"].values

        # Optical + oxygen (if exist)
        if "wlbbfl2_results_time" in ds:
            ftime = ds["wlbbfl2_results_time"].values

            if "wlbbfl2_sig695nm_adjusted" in ds:
                fluo_var = "wlbbfl2_sig695nm_adjusted"
                bb_var   = "wlbbfl2_sig700nm_adjusted"
                cdom_var = "wlbbfl2_sig460nm_adjusted"

            elif "wlbbfl2_sig695nm" in ds:
                fluo_var = "wlbbfl2_sig695nm"
                bb_var   = "wlbbfl2_sig700nm"
                cdom_var = "wlbbfl2_sig460nm"

            else:
                fluo = bb = cdom = np.full_like(time, np.nan)

            # Only run if variables exist
            if "fluo_var" in locals():
                fluo = interp_to_time(ftime.astype(float), ds[fluo_var].values, time.astype(float))
                bb   = interp_to_time(ftime.astype(float), ds[bb_var].values, time.astype(float))
                cdom = interp_to_time(ftime.astype(float), ds[cdom_var].values, time.astype(float))

        if "aanderaa4831_results_time" in ds:
            oxy_time = ds["aanderaa4831_results_time"].values

            oxygen = interp_to_time(
                oxy_time.astype(float),
                ds["aanderaa4831_dissolved_oxygen"].values,
                time.astype(float)
            )

            oxy_qc = ds["aanderaa4831_dissolved_oxygen_qc"].values.astype(int)

            oxygen_qc = interp_to_time(
                oxy_time.astype(float),
                oxy_qc,
                time.astype(float)
            )
        else:
            oxygen = np.full_like(time, np.nan)
            oxygen_qc = np.full_like(time, np.nan)
        
        # Split into down/up casts
        max_idx = np.argmax(depth)

        splits = [
            (slice(0, max_idx)),
            (slice(max_idx + 1, None))
        ]

        for s in splits:
            if len(time[s]) == 0:
                continue

            t = time[s]

            # Create time QC variable
            time_qc = np.ones_like(time, dtype=np.int8)
            ll = (time == -1e34)
            time_qc[ll] = -127

            data_dict = {
                "time": ("time", t),
                "time_qc": ("time", time_qc[s]),
                "trajectory": (ds['trajectory'].values[s]),
                "depth": ("time", fill_nan(depth[s])),
                "lat": ("time", lat[s]),
                "lon": ("time", lon[s]),
                "pressure": ("time", pressure[s]),
                "temperature": ("time", fill_nan(temperature[s])),
                "salinity": ("time", fill_nan(salinity[s])),
                "conductivity": ("time", fill_nan(conductivity[s])),
                "density": ("time", fill_nan(density[s])),
                "fluorescence": ("time", fill_nan(fluo[s])),
                "cdom": ("time", fill_nan(cdom[s])),
                "opbs": ("time", fill_nan(bb[s])),
                "oxygen": ("time", fill_nan(oxygen[s])),
                "temperature_qc": ("time", temp_qc[s].astype(int)),
                "salinity_qc": ("time", salt_qc[s].astype(int)),
                "conductivity_qc": ("time", cond_qc[s].astype(int)),                
            }

            # Create the output dataset
            out_ds = xr.Dataset(data_dict)

            # Add attributes to time variable
            out_ds["time"].attrs.update({
                "axis": "T",
                "_FillValue": -999.0,
                "anciliary_variables": "time_qc",
                "standard_name": "time",
                "long_name": "Time",
                "valid_min": str(t[0]),
                "valid_max": str(t[-1]),
                "uncertainty": 0.003,
                "observation_type": "measured",
                "sensor_name": " ",
            })

            # Add attributes to time QC variable
            out_ds["time_qc"].attrs.update({
                "_FillValue": -127,
                "anciliary_variables": "time_qc",
                "standard_name": "time status flag",
                "long_name": "Time Quality Flag",
                "valid_min": 0,
                "valid_max": 1,
                "flag_values": [0,1,2,3,4,5,6,7,8,9],
                "flag_meanings": "no_qc_preformed good_data probably_good_data bad_data_potentially_corretable bad_data value_changed interpolated_value"
            })

            out_ds["trajectory"].attrs.update({
                "cf_role": "trajectory_id",
                "comment": "A trajectory is a single deployment of a glider and may span multiple data files",
                "long_name": "Trajectory/Deployment/ Name",
            })

            out_ds["depth"].attrs.update({
                "long_name": "Depth",
                "standard_name": "depth",
                "units": "m",
                "positive": "down",
                "_FillValue": -1e34,
                "accuracy": '0.1',
                "comment": "depth of glider",
                "valid_min": 0.0,
                "valid_max": 12000.0,
                "precision": '0.1',
                "resolution": '0.1',
                "uncertainty": '0.1',
                "gts_ingest": "true",
                "reference_datum": 'sea_surface',
                "observation_type": "calculated",
                "axis": "Z",
                "platform": "platform",
                "instrument": "instrument",
                "sensor_name": " ",
                "ancillary_variables": "depth_qc",
            })

            # Add metadata (simplified)
            out_ds.attrs.update({
                "Conventions": "CF-1.6, ACDD-1.3",
                "featureType": "trajectory",
                "trajectory": deployment_name,
                "institution": "Oregon State University",
                "platform_type": "Seaglider",
                "wmo_id": wmo_id,
                "history": "Converted from raw Seaglider files"
            })

            # Output filename
            t0 = t[0]
            t0_str = np.datetime_as_string(t0, unit='s').replace("-", "").replace(":", "")
            t0_str = t0_str.replace("T", "T")

            outfile = os.path.join(
                output_dir,
                f"{g_id}_{t0_str}_rt0.nc"
            )

            print(f"Writing: {outfile}")

            out_ds.to_netcdf(outfile)

        ds.close()

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Convert raw Seaglider NetCDF files to IOOS format")
    parser.add_argument("-g", type=str, required=True)
    parser.add_argument("-i", type=str, required=True)
    parser.add_argument("-d", type=str, required=True)

    args = parser.parse_args()
    glider_to_IOOS_seaglider(
        glider_id=args.g,
        input_dir=args.i,
        deployment_name=args.d
    )