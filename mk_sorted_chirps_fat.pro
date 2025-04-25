; ------------------------------------------------------------------------------------
; 
; MK_SORTED_CHIRPS_FAT reads in daily CHIRPS3 16 day accum data to return a sorted
;   16 day array of historical CHIRPS3. The historical record is "fattened" by
;   adding the historical records of 16 day accumulations for n_days_sep both
;   before and after the given day of the month. The missing_yrs_list is used
;   to both pass in known years of missing data and it is modified to reflect
;   any other years where missing data was found. A comparison of the given
;   and returned lists informs whether new missing data was encountered.
;   
;   
; ------------------------------------------------------------------------------------

function mk_sorted_chirps_fat, month, day, missing_yrs_list, yr_start=yr_start, n_days_sep=n_days_sep, $
  no_fat=no_fat, no_sort=no_sort, dissag_method=dissag_method
  
  if ~ keyword_set(dissag_method) then dissag_method = 'IMERGlate'
  
  if dissag_method eq 'IMERGlate' then begin
    chirps_dir = '/home/scratch-GEFS/CHIRPS/v3.0.IMERGlate_v07/rolling_16day/data/'
    ;sorted_dir = '/home/scratch-GEFS/CHIRPS/v3.0.IMERGlate_v07/rolling_16day/data/sorted/'
  endif else if dissag_method eq 'ERA5' then begin
    chirps_dir = '/home/scratch-GEFS/CHIRPS/v3.0.ERA5/rolling_16day/data/'  ; 16day_CHIRPS-v3.0_data.20160820_20160904.tif
  end
  
  missing_val = -9999.0
  chirps_x_size = 7200
  chirps_y_size = 2400
  
  fattener = 3
  if keyword_set(no_fat) then fattener = 1
  
  !path = '/home/chc-source/marty/CHIRPS3-GEFS/Default/utilities:' + !path

  ; ----------------------------------------
  
  print, 'In MK_SORTED_CHIRPS_FAT: ',month,'/',day, f='(/a,i02,a,i02/)'
  tic
  
  if ~ keyword_set(yr_start) then yr_start = 2000
  if ~ keyword_set(n_days_sep) then n_days_sep = 5
  if ~ keyword_set(no_sort) then no_sort = 0

  
  n_missing_init = missing_yrs_list.count()
  
  if n_missing_init gt 0 then print, 'Years to skip: ', missing_yrs_list, f='(/,2a,/)'

  caldat, julday(), mo, dy, yr
  yr_end = yr - 1
  n_years = yr_end - yr_start + 1

  print, 'Allocating memory for CHIRPS historic data...'
  chirps = fltarr(chirps_x_size, chirps_y_size, (n_years - n_missing_init)*fattener)
  help, chirps
  
  i = 0
  for yr=yr_start, yr_end do begin
    
    print, ''
    if missing_yrs_list.where(yr) ne !NULL then begin
      print, 'SKIPPING Year, ', yr, '  ***', f='(/,a,i0,a,/)'
      continue
    endif
    
    ; -------

    search_path = string(chirps_dir, '16day_CHIRPS-v3.0_data.', yr,month,day,'_*.tif', f='(a,a,i4,i02,i02,a)')
    file_path = file_search(search_path, count=n_files)
    if n_files eq 0 then begin
      print, 'MISSING Year, ', yr, '  ***', search_path, f='(/,a,i0,a,/,a,/)'
      missing_yrs_list.add, yr
      continue
    endif
    if n_files ne 1 then message, 'Not a unique match fo file: ' + search_path

    print, 'reading: ', file_path
    data = reverse(read_tiff(file_path), 2)
    chirps[*,*,i++] = data
    
    ; fatten the time series 
    if fattener gt 1 then begin
      caldat, (julday(month, day, yr) - n_days_sep), mo1, dy1, yr1
      
      search_path = string(chirps_dir, '16day_CHIRPS-v3.0_data.', yr1, mo1, dy1,'_*.tif', f='(a,a,i4,i02,i02,a)')
      file_path = file_search(search_path, count=n_files)
      if n_files eq 0 then begin
        print, 'MISSING Year, ', yr, '  ***', search_path, f='(/,a,i0,a,/,a,/)'
        missing_yrs_list.add, yr
        i--
        continue
      endif
      if n_files ne 1 then message, 'Not a unique match fo file: ' + search_path
  
      print, 'reading: ', file_path
      data = reverse(read_tiff(file_path), 2)
      chirps[*,*,i++] = data
  
  
      caldat, (julday(month, day, yr) + n_days_sep), mo2, dy2, yr2
  
      search_path = string(chirps_dir, '16day_CHIRPS-v3.0_data.', yr2, mo2, dy2,'_*.tif', f='(a,a,i4,i02,i02,a)')
      file_path = file_search(search_path, count=n_files)
      if n_files eq 0 then begin
        print, 'MISSING Year, ', yr, '  ***', search_path, f='(/,a,i0,a,/,a,/)'
        missing_yrs_list.add, yr
        i -= 2
        continue
      endif
      if n_files ne 1 then message, 'Not a unique match fo file: ' + search_path
  
      print, 'reading: ', file_path
      data = reverse(read_tiff(file_path), 2)
      chirps[*,*,i++] = data
      
    endif
    
  endfor
  
  ; trim data array if more missing data found
  n_missing = missing_yrs_list.count()
  if n_missing gt n_missing_init then begin
    n_found = n_missing - n_missing_init
    i_end = (n_years * fattener) - (n_found * fattener) - 1
    print, 'i_end: 0:', i_end
    chirps = chirps[*,*,0:i_end]
  endif
  ;help, chirps
  
  ; Now sort the data
  if ~ no_sort then begin
    
    print, 'Sorting CHIRPS3: ',month,'/',day, f='(/a,i02,a,i02/)'
    
    for x=0, chirps_x_size-1 do begin
      
      if x mod 1000 eq 0 then print, x
      
      for y=0, chirps_y_size-1 do begin
        ts = chirps[x, y, *]
        sorted_ts = ts[sort(ts)]
        chirps[x, y, *] = sorted_ts
      endfor
    endfor
  endif
  
  toc
  print, 'fini!'
  return, chirps
end