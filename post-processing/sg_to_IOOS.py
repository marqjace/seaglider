#!/usr/bin/env python3

import glob
import xarray as xr
import numpy as np
import os
import argparse

def sg_to_IOOS(filepath):
    ds = xr.open_dataset(filepath)

    # save original attributes and encodings before processing
    global_attrs = ds.attrs

    var_attrs = {
        var: ds[var].attrs
        for var in ds.variables
    }

    encodings = {
        var: ds[var].encoding
        for var in ds.variables
    }

    # sort first
    ds = ds.sortby("time")

    # convert to dataframe
    df = ds.to_dataframe().reset_index()

    # combine duplicate timestamps
    df = (
        df.groupby("time", dropna=False)
        .agg(lambda x: x.dropna().iloc[0] if x.notna().any() else np.nan)
        .reset_index()
    )

    # convert back
    ds = xr.Dataset.from_dataframe(df.set_index("time"))

    # restore global attrs
    ds.attrs = global_attrs

    # restore variable attrs and encodings
    for var in ds.variables:
        if var in var_attrs:
            ds[var].attrs = var_attrs[var]
        if var in encodings:
            ds[var].encoding = encodings[var]

    # --- variables ---
    vars_to_interp = [
        'wlbbfl2_sig695nm_adjusted',
        'wlbbfl2_sig460nm_adjusted',
        'wlbbfl2_sig700nm_adjusted',
        'dissolved_oxygen'
    ]

    # skip missing variables, but warn and skip if none found
    processed_any = False

    for var in vars_to_interp:
        if var in ds:
            try:
                ds[var] = ds[var].interp(time=ds["temperature"].time)
                processed_any = True
            except Exception as e:
                print(f"\n{filepath}: failed on {var}: {e}")
        else:
            print(f"\n{filepath}: missing {var}, skipping")

    if not processed_any:
        print(f"\nSkipping {filepath}: no variables found")
        return
    
    
    rename_map = {
        'wlbbfl2_sig695nm_adjusted': 'fluorescence',
        'wlbbfl2_sig460nm_adjusted': 'cdom',
        'wlbbfl2_sig700nm_adjusted': 'opbs'
    }

    # Keep only variables that exist in the dataset
    rename_map = {k: v for k, v in rename_map.items() if k in ds}

    # Only rename if there's something to rename
    if rename_map:
        ds = ds.rename_vars(rename_map)

    out_dir = os.path.join(os.path.dirname(filepath), "gliderdac_proc")

    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, os.path.basename(filepath))

    ds.to_netcdf(out_path, mode='w')
    ds.close()

    print(f"\nProcessed: {filepath}")


def main():
    parser = argparse.ArgumentParser(
        description="Interpolate variables in NetCDF files onto a common time grid"
    )

    parser.add_argument(
        "-i", "--input_dir",
        help="Directory containing input files"
    )

    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Reprocess files even if output already exists"
    )

    args = parser.parse_args()

    files = sorted(glob.glob(os.path.join(args.input_dir, "*.nc")))

    if not files:
        print(f"\nNo files found in {args.input_dir}")
        return

    out_dir = os.path.join(args.input_dir, "gliderdac_proc")
    os.makedirs(out_dir, exist_ok=True)

    for f in files:

        out_path = os.path.join(out_dir, os.path.basename(f))

        # skip already processed files
        if os.path.exists(out_path) and not args.overwrite:
            print(f"Skipping existing file: {os.path.basename(f)}")
            continue

        try:
            sg_to_IOOS(f)
        except Exception as e:
            print(f"\nFailed on {f}: {e}")


if __name__ == "__main__":
    main()