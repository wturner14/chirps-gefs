;
; Updated 2025/1/25

; MK_CHIRPS_GEFS3_16DAY creates a 16 day CHIRPS-GEFS forecast from CHIRPS and GEFS 
; historical records for the same time period.
; 
; Missing_yrs is developed so that if CHIRPS or GEFS data is missing, the process stops with 
; an error. Missing_yrs variable is intiated with known missing years, 2000 for CHIRPS3 and 2020 for GEFS.
; This is passed into the mk_sorted_... routines and all missing years are returned for comparison
; testing. If more missing data is found, stop processing because something is wrong.
; *** This has not been thoroughly tested and need to be for future use. ***
; 
; reads 16 day GEFS from:
;   /home/GEFS/16day_predicts_v12/
;   /home/scratch-GEFS/CHIRPS/v3.0.ERA5/rolling_16day/data/16day_CHIRPS-v3.0_data.20160820_20160904.tif
;   /home/scratch-GEFS/CHIRPS/v3.0.IMERGlate_v07/rolling_16day/data/16day_CHIRPS-v3.0_data.20241217_20250101.tif
; writes 16 day CHIRPS-GEFS to:
;   /home/GEFS/CHIRPS-GEFS3/precip_16day/yyyy
; log file:
;   /home/GEFS/logs/mk_chirps3_gefs_16day.txt
;
; 
; ------------------------------------------------------------------------------------


pro MK_CHIRPS3_GEFS_16DAY, year, month, day, historical=historical, log_output=log_output, $
                           testing=testing, save_sorted=save_sorted
  
  compile_opt IDL2
  
  if ~ keyword_set(testing) then testing = 0
  
  var_name = 'apcp-sfc-mean'
  period = '16day'
  var = 'apcp_sfc'
  chirps_disagg_method='IMERGlate'
  n_days_sep=10
  missing_yrs = list([2000, 2020], /extract) ; this should not change...
  
  missing_yrs_init = missing_yrs
  missing_yrs_init_count = missing_yrs.count()
  new_missing_yrs_tol = 2

  ; read dirs
  gefs_fcast_dir = string('/home/GEFS/16day_precip_v12/')

  ; write dirs
  chirps_gefs_root_dir = string('/home/GEFS/CHIRPS-GEFS3/precip_16day/')
  tmp_sorted_vars_dir = '/home/scratch-GEFS/CHIRPS-GEFS_3.0/sorted_vars/' ; for dev only
  log_file = '/home/GEFS/CHIRPS3-GEFS/logs/mk_chirps_gefs3_16day.txt'
  
  !path = '/home/chc-source/marty/CHIRPS3-GEFS/Default/utilities:' + !path
  ;!path = '/home/code/idl_user_contrib/coyote:' + !path

   ; --------------------------------------------------------------

  catch, error_status

  if error_status ne 0 then begin
    printf, f_lun, 'ERROR: ' + !error_state.msg, f='(/a/)'
    if f_lun gt 0 then close, f_lun
    catch, /cancel
    retall
  endif

  f_lun = -1 ; set to -1 for standard out

  proc_clock=tic()
  
  if chirps_disagg_method eq 'ERA5' then begin
    chirps_gefs_root_dir = string('/home/GEFS/CHIRPS-GEFS3/precip_16day/ERA5/')
  endif
  
  if ~ keyword_set(save_sorted) then begin
    save_sorted = 0
  endif

  if keyword_set(log_output) then begin
    close, 1
    f_lun = 1
    close, f_lun
    if file_test(log_file) then file_delete, log_file
    openw, f_lun, log_file
  endif
  
  printf, f_lun, 'In MK_CHIRPS_GEFS3_16DAY, ', year, month, day, var, f='(/a,i4,2i3,", ",a/)'
  
  ; for running in terminal window
  resolve_routine, 'mk_sorted_gefs_fat', /is_function
  resolve_routine, 'mk_sorted_chirps_fat', /is_function
  resolve_routine, 'cgscalevector', /is_function, /no_recompile
  resolve_routine, 'cgpercentiles_ml', /is_function, /no_recompile
  resolve_routine, 'fpufix', /is_function, /no_recompile
  ;resolve_routine, 'get_ewx_file_name', /is_function, /no_recompile
   
  printf, f_lun, 'Processing day: ', year, month, day, format='(/a, i5, i3, i3/)'
 
  
  missing_val = -9999.0
  chirps_x_size = 7200
  chirps_y_size = 2400

  
  cg_predict = fltarr(chirps_x_size, chirps_y_size) + missing_val
  gefs_percentile_arr = fltarr(chirps_x_size, chirps_y_size)
  

  
  if chirps_disagg_method eq 'ERA5' then begin
    tmp_sorted_vars_dir = '/home/scratch-GEFS/CHIRPS-GEFS_3.0/sorted_vars/ERA5/' ; for dev only
  endif

  if testing then begin
    print, 'Making no fat sorted GEFS... '
    n_days_sep = 0
    
    ;gefs_sorted = mk_sorted_gefs_fat(month, day, missing_yrs, /no_fat)
    save_file=string(tmp_sorted_vars_dir, 'gefs_sorted_', n_days_sep, 'd_sep_', month, '_', day, '.sav', f='(2a,i02,a,2(i02,a))')
    ;print, 'Saving: ', save_file
    ;save, gefs_sorted, filename=save_file
    print, 'Restoring: ', save_file, f='(/,2a,/)'
    restore, filename=save_file
    
    ;gefs_unsorted = mk_sorted_gefs_fat(month, day, missing_yrs, /no_fat, /no_sort)
    save_file=string(tmp_sorted_vars_dir, 'gefs_unsorted_', n_days_sep, 'd_sep_', month, '_', day, '.sav', f='(2a,i02,a,2(i02,a))')
    ;print, 'Saving: ', save_file
    ;save, gefs_unsorted, filename=save_file
    print, 'Restoring: ', save_file, f='(/,2a,/)'
    restore, filename=save_file

;    if ~ file_test(save_file) and save_sorted then begin
;      printf, f_lun, 'Saving GEFS historic data: ', save_file, f='(/,2a,/)'
;      tic
;      save, gefs_sorted, missing_yrs, filename=save_file
;      toc
;    endif


  endif else begin
    printf, f_lun, 'Making sorted GEFS...', f='(/,2a,/)'
    gefs_sorted = mk_sorted_gefs_fat(month, day, missing_yrs, n_days_sep=n_days_sep)
    
    if missing_yrs.count() gt (missing_yrs_init_count + new_missing_yrs_tol) then begin
      new_missing_yrs_count = missing_yrs.count() - missing_yrs_init_count 
      printf, f_lun, new_missing_yrs_count, ' new missing years found after sorted GEFS. Exiting...'
      return
    endif
  endelse




  if testing then begin
    
    print, 'Making no fat sorted GEFS... '
    n_days_sep = 0
    
    ;chirps_sorted = mk_sorted_chirps_fat(month, day, missing_yrs, /no_fat)
    save_file=string(tmp_sorted_vars_dir, 'chirps_sorted_', n_days_sep, 'd_sep_', month, '_', day, '.sav', f='(2a,i02,a,2(i02,a))')
    ;print, 'Saving: ', save_file
    ;save, chirps_sorted, filename=save_file
    print, 'Restoring: ', save_file
    restore, filename=save_file

    ;chirps_unsorted = mk_sorted_chirps_fat(month, day, missing_yrs, /no_fat, /no_sort)
    save_file=string(tmp_sorted_vars_dir, 'chirps_unsorted_', n_days_sep, 'd_sep_', month, '_', day, '.sav', f='(2a,i02,a,2(i02,a))')
    ;print, 'Saving: ', save_file
    ;save, chirps_unsorted, filename=save_file
    print, 'Restoring: ', save_file
    restore, filename=save_file

  endif else begin
    printf, f_lun, 'Making sorted CHIRPS...', f='(/,2a,/)'
    chirps_sorted = mk_sorted_chirps_fat(month, day, missing_yrs, n_days_sep=n_days_sep, dissag_method=chirps_disagg_method)

    if missing_yrs.count() gt (missing_yrs_init_count + new_missing_yrs_tol) then begin
      new_missing_yrs_count = missing_yrs.count() - missing_yrs_init_count
      printf, f_lun, new_missing_yrs_count, ' new missing years found after sorted CHIRPS. Exiting...'
      return
    endif
  endelse

;  if ~ file_test(save_file) and save_sorted then begin
;    printf, f_lun, 'Saving CHIRPS historic data: ', save_file, f='(/,2a,/)'
;    save, chirps_sorted, missing_yrs, filename=save_file
;  endif
  
  if array_equal(missing_yrs_init eq missing_yrs, 0b) then message, '*** Missing_yrs returned new missing data'
  
     
  if keyword_set(historical) then begin
    gefs3_yrs=[2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2021,2022,2023,2024]
    n_yrs = n_elements(gefs3_yrs)
  endif else begin
    gefs3_yrs = year
    n_yrs = 1
  endelse


  for i=0, n_yrs-1 do begin
    
    year = gefs3_yrs[i]
  
    gefs_file_name = string('apcp-sfc.', year,month,day, '.tif', f='(a,i4,2i02,a)')
    ;gefs_file_name = get_ewx_file_name(var_name, year, month, day, period)
    gefs_accum_dir = string(gefs_fcast_dir, year, '/', month, '/', f='(a, i04, a, i02, a)')
    ;gefs_accum_dir = string(gefs_fcast_dir, year, '/', month, '/', day, '/', f='(a, i04, a, 2(i02, a))')
    gefs_file_path = gefs_accum_dir + gefs_file_name
    
    printf, f_lun, 'reading GEFS forecast: ', gefs_file_path
    g = reverse(read_tiff(gefs_file_path), 2)
    gefs = rebin(g, chirps_x_size, chirps_y_size)
     
    printf, f_lun, 'Calculating CHIRPS3-GEFS for: ', gefs_file_name, f='(/,2a,/)'
      
    tic
    gcount=0L
    ccount=0L
    n_missing_vals=0L
    
    ;
    ; Main loops to calculate CHIRPS-GEFS
    ;
    
    for x=0, chirps_x_size-1 do begin
    ;for x=ix, ix do begin
      
      if (x gt 0 and x lt 50) and ((x mod 15) eq 0) then $
        printf, f_lun, 'Working on: ', x, ' of ', chirps_x_size & flush, f_lun
      if (x mod 1000) eq 0 then $
        printf, f_lun, 'Working on: ', x, ' of ', chirps_x_size & flush, f_lun
      
      for y=0, chirps_y_size-1 do begin
      ;for y=iy, iy do begin
  
        ; get CHIRPS sorted time series (_ts) for pixel x,y
        chirps_ts = reform(chirps_sorted[x, y, *])
        ; If there are any missing values, they are all missing so skip
        ii=where(chirps_ts eq missing_val, n_missing)
        if n_missing gt 0 then begin
          ;print, 'n_missing: ', n_missing
          ;chirps_ts[ii] = 0.0
          n_missing_vals += n_missing
          ;print, string('Missing values found in CHIRPS... ', x, ', ', y)
          continue
        endif
        
        ; get GEFS sorted time series
        gefs_ts = [reform(gefs_sorted[x, y, *])]
        
        ; Get the GEFS prediction value and mins and maxs of CHIRPS and GEFS
        gefs_predict = gefs[x, y]
  
        max_chirps_ts = chirps_ts[-1]
        min_chirps_ts = chirps_ts[0]
        max_gefs_ts = gefs_ts[-1]
        min_gefs_ts = gefs_ts[0]
          
        ; Calculate the CH(RPS-GEFS value based on the GEFS percentil translated
        ; into CHIRPS sdata space.
        ; set percentile to 1.0 if gt the max GEFS
        if gefs_predict gt max_gefs_ts then begin
          ;gefs_percentile = 1.0
          cg_p = max_chirps_ts
        endif else if gefs_predict eq 0.0 then begin
          ;gefs_percentile = 0.0
          cg_p = 0.0
        endif else if gefs_predict le min_gefs_ts then begin ;ml change
          ;gefs_percentile = 0.0
          cg_p = min_chirps_ts
        endif else begin
          ; Get the indexes of the first value, in the GEFS sorted time series (gefs_ts), 
          ; that is greater than the GEFS prediction
          ii = where(gefs_ts ge gefs_predict, n)
          ; Get the number of time steps in the time series
          n_gefs = n_elements(gefs_ts)
          ; Divide the first index, or position, by the total number of years in the time 
          ; series to get the GEFS percentile, 0-1.0
          gefs_percentile = float(ii[0]) / n_gefs
          ; Calculate the value in the CHIRPS time series corresponding to the
          ; GEFS percentile using Coyote Graphics Percentiles function. _ml added the preSorted flag.
          ; cg_p is then stored in the cg_predict array
          cg_p = cgPercentiles_ml(chirps_ts, percentiles=[gefs_percentile], /preSorted)
          
        
        endelse
          
        ; Store cg_p in the CHIRPS-GEFS prediction array
        cg_predict[x, y] = cg_p
        ;gefs_percentile_arr[x, y] = gefs_percentile
          
      endfor
    endfor
      
    toc
    printf, f_lun, 'Number of missing values filled with zeros: ', n_missing_vals, f='(/a,i0,/)'
     
    ; write CHIRPS-GEFS3  
    CG_p05Deg_gtag = { $
      ModelTiepointTag: [0, 0, 0, -180, 60,0], ModelPixelScaleTag: [0.05, 0.05, 0],  $
      GTModelTypeGeoKey: 2, GTRasterTypeGeoKey: 1, GeographicTypeGeoKey: 4326,  $
      GeogAngularUnitsGeoKey: 9102s   $
    }
  
    cg_file_name = string('precip_16day_', year, month, day, '.tif', f='(a,i4,2i02,a)')
    cg_dir = string(chirps_gefs_root_dir, year, '/', month, '/', f='(a,i4,a,i02,a)')
    if ~ file_test(cg_dir, /dir) then file_mkdir, cg_dir
    
    printf, f_lun, 'Writing to EWX: ', cg_dir + cg_file_name
    write_tiff, cg_dir + cg_file_name, reverse(cg_predict, 2), /float, geotiff=CG_p05Deg_gtag
  
    printf, f_lun,''
    
  end

  printf, f_lun, 'fini!'
  
  toc, proc_clock
  
  if f_lun ne -1 then close, f_lun
  
  print, 'fini!'
  
end


;        if ix eq x and iy eq y then begin
;          gefs3_yrs=  [2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2021,2022,2023,2024]
;          chirps3_yrs=[2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2021,2022,2023,2024]
;
;          print, '******** CHIRPS-GEFS 3 ***************'
;          print, 'X: ', ix, ', Y: ', iy
;          print, 'GEFS predict: ', gefs_predict, f='(a,f0.6)'
;          print, 'GEFS percentile: ', gefs_percentile
;          print, 'CHIRPS-GEFS3: ', cg_p
;          print, '************************************'
;          print, ''
;          n_yrs = n_elements(gefs_ts)
;
;          gefs_pers = findgen(n_yrs) / n_yrs
;
;          print, ' CHIRPS     GEFS%      GEFS'
;          for z=0, n_yrs-1 do begin
;            print, chirps_ts[z], gefs_pers[z], gefs_ts[z], f='(f8.3, f9.3, f11.3)'
;          endfor
;
;
;          gefs_un_ts = [reform(gefs_unsorted[x, y, *])]
;          ii_sort = sort(gefs_un_ts)
;
;          print, ' GEFS    Year   sorted', f='(/a)'
;          for z=0, n_yrs-1 do print, gefs_un_ts[ii_sort[z]], gefs3_yrs[ii_sort[z]], f='(f8.3, i7)'
;
;          print, ' GEFS    Year   unsorted', f='(/a)'
;          for z=0, n_yrs-1 do print, gefs_un_ts[z], gefs3_yrs[z], f='(f8.3, i7)'
;
;
;          chirps_un_ts = [reform(chirps_unsorted[x, y, *])]
;          ii_sort = sort(chirps_un_ts)
;
;          print, ' CHIRPS    Year   sorted', f='(/a)'
;          for z=0, n_yrs-1 do print, chirps_un_ts[ii_sort[z]], chirps3_yrs[ii_sort[z]], f='(f8.3, i7)'
;
;          print, ' CHIRPS    Year   unsorted', f='(/a)'
;          for z=0, n_yrs-1 do print, chirps_un_ts[z], chirps3_yrs[z], f='(f8.3, i7)'
;
;          pause='here'
;        endif

