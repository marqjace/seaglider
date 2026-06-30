#!/usr/bin/env python3

import glob
import xarray as xr
import numpy as np
import os
import argparse

def sg_to_IOOS(filepath):
    with xr.open_dataset(filepath) as src_ds:
        if "time" not in src_ds.coords:
            print(f"\nSkipping {filepath}: missing time coordinate")
            return

        ds = src_ds.sortby("time")

        # Deduplicate along the time dimension while keeping full dataset structure.
        _, unique_idx = np.unique(ds["time"].values, return_index=True)
        unique_idx = np.sort(unique_idx)
        ds = ds.isel(time=unique_idx)

        # Use temperature sampling times when available; otherwise keep native time.
        target_time = ds["time"]
        if "temperature" in ds and "time" in ds["temperature"].dims:
            try:
                temp_time = ds["temperature"].dropna(dim="time")["time"]
                if temp_time.size > 0:
                    target_time = temp_time
            except Exception:
                target_time = ds["time"]

        vars_to_interp = [
            "wlbbfl2_sig695nm_adjusted",
            "wlbbfl2_sig460nm_adjusted",
            "wlbbfl2_sig700nm_adjusted",
            "dissolved_oxygen",
        ]

        processed_any = False

        for var in vars_to_interp:
            if var not in ds:
                print(f"\n{filepath}: missing {var}, skipping")
                continue

            if "time" not in ds[var].dims:
                print(f"\n{filepath}: {var} has no time dimension, skipping")
                continue

            attrs = ds[var].attrs.copy()
            encoding = ds[var].encoding.copy()

            try:
                if ds[var].ndim != 1:
                    print(f"\n{filepath}: {var} is not 1D along time, skipping")
                    continue

                src_da = ds[var].dropna(dim="time")
                if src_da.size < 2:
                    print(f"\n{filepath}: insufficient finite points in {var}, skipping")
                    continue

                src_t = src_da["time"].values.astype("datetime64[ns]").astype(np.int64)
                src_v = src_da.values.astype(float)
                valid = np.isfinite(src_v)

                if valid.sum() < 2:
                    print(f"\n{filepath}: insufficient valid points in {var}, skipping")
                    continue

                tgt_t = target_time.values.astype("datetime64[ns]").astype(np.int64)
                interp_v = np.interp(
                    tgt_t,
                    src_t[valid],
                    src_v[valid],
                    left=np.nan,
                    right=np.nan,
                )

                interp_da = xr.DataArray(
                    interp_v,
                    coords={"time": target_time.values},
                    dims=("time",),
                    name=var,
                )
                interp_da.attrs = attrs
                interp_da.encoding = encoding
                ds[var] = interp_da
                processed_any = True
            except Exception as e:
                print(f"\n{filepath}: failed on {var}: {e}")

        if not processed_any:
            print(f"\nSkipping {filepath}: no variables found")
            return

        rename_map = {
            "wlbbfl2_sig695nm_adjusted": "mass_concentration_of_chlorophyll_a_in_sea_water",
            "wlbbfl2_sig460nm_adjusted": "concentration_of_colored_dissolved_organic_matter_in_sea_water",
            "wlbbfl2_sig700nm_adjusted": "volume_backwards_scattering_coefficient_of_radiative_flux_in_sea_water",
        }

        rename_map = {k: v for k, v in rename_map.items() if k in ds}
        if rename_map:
            ds = ds.rename_vars(rename_map)

        out_dir = os.path.join(os.path.dirname(filepath), "gliderdac_proc")
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, os.path.basename(filepath))

        ds.to_netcdf(out_path, mode="w")
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