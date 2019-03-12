# Source Mappings

Different data providers have different terms for the same observed properties, the same units of measurement, or the same unit symbols. These have to be converted in the Data Transloader to a standard set.

The mappings used for each data provider are listed below.

## Campbell Scientific

Source Property  |  Source Units  |  STA Observed Property  |  STA Units
-----------------|----------------|-------------------------|-----------
BattV_Avg        |  Volts         |                         |
BP_Avg           |  kPa           |                         |
CO2_Avg          |                |                         |
CO2_op_Avg       |                |                         |
GUST_Max         |  km/hr         |                         |
H2O_Avg          |                |                         |
H2O_op_Avg       |                |                         |
Kdn_Avg          |  W/m^2         |                         |
Kup_Avg          |  W/m^2         |                         |
LdnCo_Avg        |  W/m^2         |                         |
LupCo_Avg        |  W/m^2         |                         |
mfc_Avg          |                |                         |
Pfast_cp_Avg     |                |                         |
RH_B_Avg         |                |                         |
TEMPERATURE_Avg  |  Deg C         |                         |
Ux_Avg           |                |                         |
Uy_Avg           |                |                         |
Uz_Avg           |                |                         |
WIND_DIRECTION   |  Deg           |                         |
WIND_SPEED       |                |                         |
xco2_cp_Avg      |                |                         |
xh2o_cp_Avg      |                |                         |


## Data Garrison

Source Property   |  Source Units  |  STA Observed Property  |  STA Units
------------------|----------------|-------------------------|-----------
Backup Batteries  |  V             |                         |
Gust Speed        |  km/h          |                         |
Pressure          |  mbar          |                         |
RH                |  %             |                         |
Temperature       |  *C            |                         |
Wind Direction    |  deg           |                         |
Wind Speed        |  km/h          |                         |


## Environment Canada

Properties and units sourced from [PDF](http://dd.weather.gc.ca/observations/doc/SWOB-ML_Product_User_Guide_v8.2_e.pdf). A complete list of properties has not been converted, as there are many duplicates across different sub-providers.

Source Property                    |  Source Units  |  STA Observed Property  |  STA Units
-----------------------------------|----------------|-------------------------|-----------
air_temp                           |  ˚C            |                         |
air_temp_12hrs_ago                 |  ˚C            |                         |
altmetr_setng                      |  inHg          |                         |
avg_air_temp_pst1hr                |  ˚C            |                         |
avg_cum_pcpn_gag_wt_fltrd_mt55-60  |  mm            |                         |
avg_globl_solr_radn_pst1hr         |  W/m2          |                         |
avg_wnd_dir_10m_mt50-60            |  ˚             |                         |
avg_wnd_dir_10m_mt58-60            |  ˚             |                         |
avg_wnd_dir_10m_pst1hr             |  ˚             |                         |
avg_wnd_spd_10m_mt50-60            |  km/h          |                         |
avg_wnd_spd_10m_mt58-60            |  km/h          |                         |
avg_wnd_spd_10m_pst1hr             |  km/h          |                         |
avg_wnd_spd_pcpn_gag_mt50-60       |  km/h          |                         |
cld_amt_code_1                     |  code          |                         |
cld_amt_code_2                     |  code          |                         |
cld_amt_code_3                     |  code          |                         |
cld_bas_hgt_1                      |  m             |                         |
cld_bas_hgt_2                      |  m             |                         |
cld_bas_hgt_3                      |  m             |                         |
cld_typ_1                          |  code          |                         |
cld_typ_2                          |  code          |                         |
cld_typ_3                          |  code          |                         |
data_avail                         |  %             |                         |
dwpt_temp                          |  ˚C            |                         |
hdr_fwd_pwr                        |  W             |                         |
hdr_oscil_drft                     |  Hz            |                         |
hdr_refltd_pwr                     |  W             |                         |
hdr_suply_volt                     |  V             |                         |
logr_panl_temp                     |  ˚C            |                         |
max_air_temp_pst1hr                |  ˚C            |                         |
max_air_temp_pst24hrs              |  ˚C            |                         |
max_air_temp_pst6hrs               |  ˚C            |                         |
max_batry_volt_pst1hr              |  V             |                         |
max_pk_wnd_spd_10m_pst1hr          |  km/h          |                         |
max_rel_hum_pst1hr                 |  %             |                         |
max_vis_mt50-60                    |  km            |                         |
max_wnd_gst_spd_10m_mt50-60        |  km/h          |                         |
max_wnd_spd_10m_mt50-60            |  km/h          |                         |
max_wnd_spd_10m_pst1hr             |  km/h          |                         |
max_wnd_spd_10m_pst1hr_tm          |  km/h          |                         |
min_air_temp_pst1hr                |  ˚C            |                         |
min_air_temp_pst24hrs              |  ˚C            |                         |
min_air_temp_pst6hrs               |  ˚C            |                         |
min_batry_volt_pst1hr              |  V             |                         |
min_rel_hum_pst1hr                 |  %             |                         |
min_vis_mt50-60                    |  km            |                         |
mslp                               |  hPa           |                         |
pcpn_amt_pst1hr                    |  mm            |                         |
pcpn_amt_pst24hrs                  |  mm            |                         |
pcpn_amt_pst3hrs                   |  mm            |                         |
pcpn_amt_pst6hrs                   |  mm            |                         |
pcpn_snc_last_syno_hr              |  mm            |                         |
pk_wnd_rmk                         |  unitless      |                         |
pres_tend_amt_pst3hrs              |  hPa           |                         |
pres_tend_char_pst3hrs             |  code          |                         |
prsnt_wx_1                         |  code          |                         |
rel_hum                            |  %             |                         |
rmk                                |  unitless      |                         |
rnfl_amt_pst1hr                    |  mm            |                         |
rnfl_snc_last_syno_hr              |  mm            |                         |
snw_dpth                           |  cm            |                         |
snw_dpth_1                         |  cm            |                         |
snw_dpth_2                         |  cm            |                         |
snw_dpth_3                         |  cm            |                         |
stn_pres                           |  hPa           |                         |
tot_globl_solr_radn_pst1hr         |  kJ/m2         |                         |
vert_vis                           |  m             |                         |
vis                                |  km            |                         |
wnd_dir_10m_mt50-60_max_spd        |  ˚             |                         |
wnd_dir_10m_pst1hr_max_spd         |  ˚             |                         |
wnd_dir_10m_pst1hr_pk_spd          |  ˚             |                         |


## SensorThings API Observed Properties

WIP: More details on target Observed Properties

## SensorThings API Units of Measurement

WIP: More details on target Units
