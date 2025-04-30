;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GEFS_CRON_STEP3 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;-----------------------------------------------------------------------------------------------;
; THIS SCRIPT ...                               ;
;-----------------------------------------------------------------------------------------------;
;-----------------------------------------------------------------------------------------------;
; OUTPUT                                                                                        ;
;
;-----------------------------------------------------------------------------------------------;
;-----------------------------------------------------------------------------------------------;
; PRIMARY SCRIPTS USED                                                                          ;
;
;-----------------------------------------------------------------------------------------------;
;-----------------------------------------------------------------------------------------------;
; EXAMPLE USEAGE                                                                                ;
;
;-----------------------------------------------------------------------------------------------;
;-----------------------------------------------------------------------------------------------;
; ADAPTED FROM:                                                                                 ;
;   /home/chc-source/marty/CHIRPS3-GEFS/Default/cron/mk_gefs_op_v12_dailies.pro                 ;
;                                                                                               ;
; Procedure/Adaptations Written: Will Turner, UCSB Climate Hazards Center, 25 April 2025        ;
;   Status:                                                                                     ;
;   [ ] : Stable, Operational                                                                   ;
;   [X] : Development (May be operational but subject to change/edits)                          ;
;   [ ] : Exploratory (Designed for command line or non-automated useage)                       ;
;-----------------------------------------------------------------------------------------------;


; MK_GEFS_OP_V12_DAILIES_16DAY
; Creates 16 daily precipitation forecast accumulation files from GEFS GRIB data,
; and also generates a 16-day total accumulation file.
; It writes the GRIB file out to a NetCDF because working with GRIBS is redick!
; 
;
; reads from:
;   /home/GEFS/operational_v12/grib/yyyy/mm/dd/geavg.t00z.pgrb2a.0p50.f348
;   
; Output goes to:
;   /home/GEFS/daily_precip_v12/yyyy/mm/dd
;   /home/GEFS/16day_precip_v12/yyyy/mm/
;   
; Log written to:
;   /home/GEFS/CHIRPS3-GEFS/logs/mk_gefs_op_v12_dailies_16day.txt
;
; Example usage:
;   mk_gefs_op_v12_dailies_16day, 2024, 8, 5
;   or
;   run across a date range with loops.
;   for yr=2025, 2025 do for mo=1, 4 do for dy=1,n_days_month(yr,mo)-1 do mk_gefs_op_v12_dailies_16day, yr, mo, dy
;   
;   
;   yrs=[2000,2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2021,2022,2023,2024]
;   n_yrs = n_elements(yrs)
;   mo = 4
;   n_days = n_days_month(1999,mo) 
;   for i=0, n_yrs-1 do for dy=1, n_days do mk_gefs_op_v12_dailies_16day, yrs[i], mo, dy
;   
;   TODO:
;     write a copy for EWX to:  /home/chc-data-out/products/EWX2/GEFS/gefs_global_16day_data/
;

pro MK_GEFS_OP_V12_DAILIES_16DAY, year, month, day, log_output=log_output, $
  no_delete=no_delete

  COMPILE_OPT IDL2  ; Use IDL2 compatibility mode for better syntax checking

  ;--- Define input/output directories ---
  grib_file_dir_root = '/home/GEFS/operational_v12/grib/' ; Input GRIB directory
  ncdf_dir = '/home/scratch-GEFS/data_ncdf/'                 ; Temp NetCDF directory

  daily_dir_root = '/home/GEFS/daily_precip_v12/'     ; Daily output dir
  dir_16day_root = '/home/GEFS/16day_precip_v12/' ; 16-day output dir ;previously... /home/scratch-GEFS/GEFS_16day_predicts_v12/

  log_file = '/home/GEFS/CHIRPS3-GEFS/logs/mk_gefs_op_v12_dailies_16day.txt' ; Log file path

  var = 'apcp_sfc'         ; Variable short name
  var_name = 'APCP_surface' ; NetCDF variable name

  ;--- Handle logging ---
  f_lun = -1 ; Default to terminal output
  if keyword_set(log_output) then f_lun = 1

  if f_lun gt 0 then begin
    close, f_lun
    if file_test(log_file) then file_delete, log_file
    print, 'LOGGING to: ', log_file
    openw, f_lun, log_file
  endif

  ;--- Error handling setup ---
  catch, error_status
  if error_status ne 0 then begin
    printf, f_lun, 'ERROR: ' + !error_state.msg
    if f_lun gt 0 then close, f_lun
    catch, /cancel
    retall
  endif

  ;--- Resolve helper routines if necessary ---
  resolve_routine, 'n_days_month', /is_function
  resolve_routine, 'is_leap', /is_function

  ;--- Define geotag info for 0.25 degree TIFFs ---
  GEFS_p25Deg_gtag = {ModelTiepointTag: [0, 0, 0, -180, 50, 0], $
    ModelPixelScaleTag:[0.25, 0.25, 0], $
    GTModelTypeGeoKey: 2, GTRasterTypeGeoKey: 1, $
    GeographicTypeGeoKey: 4326, GeogAngularUnitsGeoKey: 9102s}

  ;--- Grid and time definitions ---
  gefs_x_size = 1440
  gefs_y_size = 721
  n_hours = 384     ; 16 days * 24 hours
  n_times = 64      ; 384 / 6-hour intervals

  n_days = n_days_month(year, month) ; Get number of days in the month

  yrmodyhr = string(year, month, day, '00', f='(i4, i02, i02, a)')
  printf, f_lun, 'In operational/MK_GEFS_OP_v12_DAILIES_16DAY, working on: ' + yrmodyhr, f='(/a/)'

  ;--- Preallocate precipitation data array ---
  i_time = 0
  precip = fltarr(gefs_x_size, gefs_y_size, n_times)

  ;--- Loop through all 6-hour forecast steps ---
  for t=6, n_hours, 6 do begin
    
    ; Build GRIB file path and NetCDF output filename
    gefs_download_dir = string(grib_file_dir_root, year, month, day, f='(a,i4,"/",i02,"/",i02,"/")')
    gefs_search_str = string(gefs_download_dir, 'geavg.t*.f', t, f='(2a, i03)')
    printf, f_lun, 'Searching for: ', gefs_search_str
    gefs_file_path = file_search(gefs_search_str, count=n_files)
    if n_files ne 1 then message, 'ERROR: File not found: ' + gefs_search_str

    ncdf_file_name = string(ncdf_dir, var_name, '_', yrmodyhr, '.nc', f='(5a)')

    ; Check if GRIB file exists
    if ~ file_test(gefs_file_path) then message, 'ERROR: File not found: ' + gefs_file_path

    ; Convert GRIB to NetCDF using wgrib2
    cmd = string('wgrib2 ', gefs_file_path, ' -netcdf ', ncdf_file_name, f='(4a)')
    printf, f_lun, cmd
    spawn, cmd, res, err

    ; Open NetCDF and read in variable
    nc_id = ncdf_open(ncdf_file_name, /nowrite)
    uid  = ncdf_varid(nc_id, var_name)
    ncdf_varget, nc_id, uid, apcp_sfc
    ncdf_close, nc_id

    ; Resize to 0.25° resolution if needed
    sz = size(apcp_sfc, /dimensions)
    if sz[0] ne gefs_x_size then begin
      printf, f_lun, 'resizing to 0.25 deg...', sz[0], ', ', gefs_x_size
      apcp_sfc = congrid(apcp_sfc, gefs_x_size, gefs_y_size, /center, /interp)
    endif

    ; Store in main data array
    precip[*, *, i_time++] = apcp_sfc

    ; (Optional) Delete GRIB files — currently disabled
    ; if ~ keyword_set(no_delete) then file_delete, gefs_file_path
  endfor

  ;--- Shift longitudes: center on 0°, like CHIRPS ---
  tmp_precip = precip
  precip[0:719, *, *] = tmp_precip[720:1439, *, *]
  precip[720:1439, *, *] = tmp_precip[0:719, *, *]

  ; limit to 60 degrees N & S
  i_north = 120
  i_south = 599
  tmp_precip = precip
  precip = tmp_precip[*, i_north:i_south, *]

;  ;--- Trim to latitudes 50°N–50°S ---
;  tmp_precip = precip
;  precip = tmp_precip[*, 160:559, *]

  ;--- Create daily directory if needed ---
  daily_dir = string(daily_dir_root, year, month, day, '/', f='(a,i4,"/",i02,"/",i02, a)')
  if ~ file_test(daily_dir, /directory) then file_mkdir, daily_dir

  ;--- Initialize daily and total accumulation arrays ---
  precip_daily = precip[*, *, 0]
  precip_total = precip_daily
  i_day = 0

  ;--- Loop to calculate and write daily accumulations ---
  for i=1, n_times do begin
    precip_daily += precip[*, *, i-1] ; 6-hourly sum

    ; Write output every 24 hours (4 time steps)
    if ((i*6) mod 24) eq 0 and i ne 0 then begin
      i_neg_mask = where(precip_daily lt 0.0, n_neg)
      if n_neg gt 0 then precip_daily[i_neg_mask] = 0.0

      jday = julday(month, day, year) + i_day
      caldat, jday, mo, dy, yr

      file_name = string(var, '.', yr, mo, dy, '.tif', f='(2a,i4,i02,i02,a)')
      printf, f_lun, 'Writing: ' + daily_dir + file_name

      write_tiff, daily_dir + file_name, reverse(precip_daily, 2), $
        geotiff=GEFS_p25Deg_gtag, /float, compress=1

      precip_total += precip_daily
      i_day++
      precip_daily *= 0.0 ; reset daily sum
    endif
  endfor

  ;--- Write 16-day accumulated total ---
  gefs_accum_dir = string(dir_16day_root, year, month, f='(a,i4,"/",i02,"/")')
  if ~ file_test(gefs_accum_dir, /directory) then file_mkdir, gefs_accum_dir

  gefs_file_name = string('apcp-sfc.', year, month, day, '.tif',f='(a,i4,2i02,a)')
  ;gefs_file_name = get_ewx_file_name('apcp-sfc-mean', year, month, day, '16day')
  printf, f_lun, 'Writing: ', gefs_accum_dir + gefs_file_name
  printf, f_lun, 'mean: ', mean(precip_total)

  write_tiff, gefs_accum_dir + gefs_file_name, reverse(precip_total, 2), $
    geotiff=GEFS_p25Deg_gtag, /float

  ;--- Clean up NetCDF file if not saving ---
  if ~ keyword_set(no_delete) then begin
    printf, f_lun, 'Deleting: ', ncdf_file_name
    file_delete, ncdf_file_name
  endif

  ;--- Finalize ---
  printf, f_lun, 'fini!'
  if f_lun eq 1 then close, f_lun

end