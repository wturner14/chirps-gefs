;
; MK_SORTED_GEFS_FAT ; rename GET_SORTED_16day_GEFS_FAT
; Reads from the GEFS 16day folder and returns a sorted fattened array. 
; The missing_yrs_list is used to both pass in known years of missing data and it is modified to reflect
;   any other years where missing data was found. A comparison of the given
;   and returned lists informs whether new missing data was encountered.
; Options include:
;   Number of days of seperation for the fattening time series
;   No fattening option
;   No sort option
;   
;   missing_yrs = list([2000, 2020], /extract)
;   
;  mk_sorted_gefs_fat, month, day, missing_yrs_list
; --------------------------------------------------

function mk_sorted_gefs_fat, month, day, missing_yrs_list, yr_start=yr_start, n_days_sep=n_days_sep, $
  no_fat=no_fat, no_sort=no_sort, gefs2=gefs2, no_resize=no_resize
  
  ; input dir
  gefs_root_dir = string('/home/GEFS/16day_precip_v12/')
  fname_prefix = 'apcp-sfc.'
  gefs_root_dir2 = string('/home/scratch-GEFS/GEFS_16day_predicts_v12/')
  fname_prefix2 = 'apcp-sfc-mean_'

  gefs_x_size = 1440
  gefs_y_size = 480
  chirps_x_size = 7200
  chirps_y_size = 2400

  missing_val = -9999.0
   
  fattener = 3
  if keyword_set(no_fat) then fattener = 1

  !path = '/home/chc-source/marty/CHIRPS3-GEFS/Default/utilities:' + !path

  ; ----------------------------------------
  
  print, 'In MK_SORTED_GEFS_FAT: ',month,'/',day, f='(/a,i02,a,i02/)'
  tic
  
  if keyword_set(gefs2) then begin
    gefs_root_dir = gefs_root_dir2
    fname_prefix = fname_prefix2
    gefs_y_size = 400
    chirps_y_size = 2000
  endif
  
  if ~ keyword_set(yr_start) then yr_start = 2000
  if ~ keyword_set(n_days_sep) then n_days_sep = 10
  if ~ keyword_set(no_sort) then no_sort = 0

  n_missing_init = missing_yrs_list.count()

  if n_missing_init gt 0 then print, 'Missing years: ', missing_yrs_list, f='(/,2a,/)'
  
  caldat, julday(), mo, dy, yr 
  yr_end = yr - 1 
;yr_end = 2005
  n_years = yr_end - yr_start + 1

  print, 'Allocating memory for GEFS historic data...'
  gefs = fltarr(gefs_x_size, gefs_y_size, (n_years - n_missing_init)*fattener)
  help, gefs
  
  i = 0
  for yr=yr_start, yr_end do begin
    
    if missing_yrs_list.where(yr) ne !NULL then begin
      print, 'SKIPPING Year, ', yr, '  ***', f='(a,i0,a)'
      continue
    endif
    
    ; -------
    
    gefs_dir = string(gefs_root_dir, yr, '/', month, '/', f='(a, i04, a, i02, a)')
    if keyword_set(gefs2) then begin
      gefs_dir = string(gefs_root_dir, yr, '/', month, '/', day, '/', f='(a, i04, a, 2(i02, a))')
    endif
    search_path = string(gefs_dir, fname_prefix, yr,month,day,'*.tif', f='(a,a,i4,i02,i02,a)')
    file_path = file_search(search_path, count=n_files)
    if n_files gt 1 then message, 'Not a unique match fo file: ' + search_path
    if n_files eq 0 then begin
      print, 'MISSING Year, ', yr, '  ***', search_path, f='(/,a,i0,a,/,a,/)'
      missing_yrs_list.add, yr
      continue
    endif
    
    print, 'reading: ', file_path, i, f='(2a, ", ", i0)'
    data = reverse(read_tiff(file_path), 2)
    siz = size(data, /dim)
    ;if keyword_set(gefs2) then begin ;;; uncomment when done testing
    if siz[1] eq 720 then begin
      print, 'Resizing GEFS ****', siz
      data = rebin(data, gefs_x_size, gefs_y_size)
    endif
    gefs[*,*,i++] = data
    
    ; -------
    if fattener gt 1 then begin

      ; add data from n_days_sep prior to the given date's time series
      caldat, (julday(month, day, yr) - n_days_sep), mo1, dy1, yr1
      
      gefs_dir = string(gefs_root_dir, yr1, '/', mo1, '/', f='(a, i04, a, i02, a)')
      search_path = string(gefs_dir, 'apcp-sfc.', yr1, mo1, dy1,'*.tif', f='(a,a,i4,i02,i02,a)')
      file_path = file_search(search_path, count=n_files)
      if n_files gt 1 then message, 'Not a unique match fo file: ' + search_path
      if n_files eq 0 then begin
        print, 'MISSING Year, ', yr, '  ***', search_path, f='(/,a,i0,a,/,a,/)'
        missing_yrs_list.add, yr
        i--
        continue
      endif
      print, 'reading: ', file_path
      data = reverse(read_tiff(file_path), 2)
      gefs[*,*,i++] = data
  
      ; -------
      
      ; add data from n_days_sep after to the given date's time series
      caldat, (julday(month, day, yr) + n_days_sep), mo2, dy2, yr2
  
      gefs_dir = string(gefs_root_dir, yr2, '/', mo2, '/', f='(a, i04, a, i02, a)')
      search_path = string(gefs_dir, 'apcp-sfc.', yr2, mo2, dy2,'*.tif', f='(a,a,i4,i02,i02,a)')
      file_path = file_search(search_path, count=n_files)
      if n_files gt 1 then message, 'Not a unique match fo file: ' + search_path
      if n_files eq 0 then begin
        print, 'MISSING Year, ', yr, '  ***', search_path, f='(/,a,i0,a,/,a,/)'
        missing_yrs_list.add, yr
        i -= 2
        continue
      endif
    
      print, 'reading: ', file_path
      data = reverse(read_tiff(file_path), 2)
      gefs[*,*,i++] = data
    endif
    
  endfor
  
  help, gefs
 
  ; trim data array if more missing data found
  n_missing = missing_yrs_list.count()
  if n_missing gt n_missing_init then begin
    print, '*** More missing data found ***'
    n_found = n_missing - n_missing_init
    i_end = (n_years * fattener) - (n_found * 3) - 1
    print, 'i_end: 0:', i_end
    gefs = gefs[*,*,0:i_end]
  endif

  if keyword_set(no_resize) then return,gefs

  ; resize to chirps3 dimensions
  siz = size(gefs, /dim)
  n_yrs = siz[2]
;  gefs = rebin(gefs, chirps_x_size, chirps_y_size, n_yrs)
  gefs_sorted = fltarr(chirps_x_size, chirps_y_size, n_yrs)
  
  for i=0, n_yrs-1 do begin
    g = rebin(gefs[*,*,i], chirps_x_size, chirps_y_size)
    gefs_sorted[*,*,i] = g
  endfor

  ; for testing. --------
  ; gefs3_unsorted = mk_sorted_gefs_fat(5, 15, list([2020],/extract), /no_fat, /no_sort)
;  gefs_test=reverse(read_tiff('/home/GEFS/16day_precip_v12/2000/05/apcp-sfc.20000515.tif'),2)
;
;  gefs_chirped=rebin(gefs_test, chirps_x_size, chirps_y_size)
;  gefs0=gefs_sorted[*,*,0]
;  ;i1=image(gefs0, max=120,tit='gefs0')
;  ;i2=image(gefs_chirped, max=120,tit='gefs_chirped')
;  dif = gefs0 - gefs_chirped
;  mve,dif ; 0.023240       5.1742      -141.52       119.56   (7200,2400) = 17280000
;  img=image(dif, min=(-20), max=20, rgb=70,tit='gefs0 - gefs_chirped ')
;
;  gefs_chirped=rebin(gefs_test, chirps_x_size, chirps_y_size)
;  gefs_sorted[*,*,0] = gefs_chirped
;  gefs0=gefs_sorted[*,*,0]
;  dif = gefs0 - gefs_chirped
;  mve,dif ; 0.0000       0.0000       0.0000       0.0000   (7200,2400) = 17280000
;  img=image(dif, min=(-20), max=20, rgb=70,tit='gefs0 - gefs_chirped ')
;  
;  
;  gefs_chirped=rebin(gefs[*,*,0], chirps_x_size, chirps_y_size)
;  gefs_sorted[*,*,0] = gefs_chirped
;  gefs0=gefs_sorted[*,*,0]
;  dif = gefs0 - gefs_chirped
;  mve,dif ; 0.0000       0.0000       0.0000       0.0000   (7200,2400) = 17280000
;
;
;  g = rebin(gefs[*,*,0], chirps_x_size, chirps_y_size)
;  gefs_sorted[*,*,0] = g
;  gefs0=gefs_sorted[*,*,0]
;  dif = gefs0 - gefs_chirped
;  mve,dif 
;  img=image(dif, min=(-20), max=20, rgb=70,tit='gefs0 - gefs_chirped ')
;
; 
;  g = gefs[*,*,0]
;  dif = g - gefs_test
;  mve,dif ; 0 0 0s
;  i1=image(g, max=120,tit='g')
;  i2=image(gefs_test, max=120,tit='gefs_test')
;  mg=image(dif, min=(-20), max=20, rgb=70,tit='g-gefs_test ')
  ; -----------------------
  
 
  ; Now sort the data 
  if ~ no_sort then begin
  
    print, 'Sorting GEFS: ',month,'/',day, f='(/a,i02,a,i02/)'
  
    for x=0, chirps_x_size-1 do begin
      
      if x mod 1000 eq 0 then print, x
      
      for y=0, chirps_y_size-1 do begin
        ts = gefs_sorted[x, y, *]
        sorted_ts = ts[sort(ts)]
        gefs_sorted[x, y, *] = sorted_ts
      endfor
    endfor
    
  endif
  
  help, gefs_sorted

  ;if missing_yrs_list.count() gt 0 then missing_yrs = missing_yrs_list.toArray()
  
  toc
  print, 'fini!'
  return, gefs_sorted
end