import glob
import numpy as np
import xarray as xr
import pandas as pd
import cmocean as cm
import matplotlib.pyplot as plt
from scipy.interpolate import griddata

# Directory containing dive files
dive_dir = r"C:\Users\marqjace\data\seaglider\sg266\mar2025_deployment"
dive_files = sorted(glob.glob(f"{dive_dir}\\p266*.nc"))

# Create lists to hold concatenated data
time_list = []
oxy_list = []
oxy_corr_list = []
depth_list = []

# Loop through each dive file and extract relevant data
for f in dive_files:
    print(f'Processing file {f}....')
    ds = xr.open_dataset(f, drop_variables=['compass_timeouts_times_truck'])

    ctd_time_days = ds['ctd_time'].values.astype('datetime64[s]').astype(float) / 86400
    oxy_time_days = ds['aanderaa4831_results_time'].values.astype('datetime64[s]').astype(float) / 86400
    depth = ds['ctd_depth'].values
    oxy = ds['aanderaa4831_dissolved_oxygen'].values
    gain = 1.0525
    oxy_calibrated = oxy * gain

    oxy_on_ctd_time = np.interp(
        ctd_time_days,
        oxy_time_days,
        oxy,
        left=np.nan,
        right=np.nan
    )

    oxy_on_ctd_time_corr = np.interp(
        ctd_time_days,
        oxy_time_days,
        oxy_calibrated,
        left=np.nan,
        right=np.nan
    )

    time_list.append(ctd_time_days)
    oxy_list.append(oxy_on_ctd_time)
    oxy_corr_list.append(oxy_on_ctd_time_corr)
    depth_list.append(depth)

    ds.close()

# Concatenate all data into single arrays
time_all = np.concatenate(time_list)
oxy_all = np.concatenate(oxy_list)
oxy_corr_all = np.concatenate(oxy_corr_list)
depth_all = np.concatenate(depth_list)

# Plotting
fig, (ax1, ax2) = plt.subplots(nrows=1, ncols=2, figsize=(12, 15))

sc1 = ax1.scatter(
    pd.to_datetime(time_all, unit='D'),
    depth_all,
    c=oxy_all,
    cmap=cm.cm.oxy,
    s=10
)

ax1.invert_yaxis()
ax1.set_ylim(1000, 0)
ax1.set_xlabel('Time')

sc2 = ax2.scatter(
    pd.to_datetime(time_all, unit='D'),
    depth_all,
    c=oxy_corr_all,
    cmap=cm.cm.oxy,
    s=10
)

ax2.invert_yaxis()
ax2.set_ylim(1000, 0)
ax2.set_xlabel('Time')
ax1.set_ylabel('Depth (m)')
ax2.set_ylabel('Depth (m)')
ax1.set_title('Dissolved Oxygen on CTD Time Grid')
ax2.set_title('Dissolved Oxygen on CTD Time Grid (Calibrated)')

plt.colorbar(sc1, ax=ax1, label='Dissolved Oxygen (µmol/kg)')
sc1.set_clim(0, 300)
plt.colorbar(sc2, ax=ax2, label='Dissolved Oxygen (µmol/kg)')
sc2.set_clim(0, 300)
plt.show()