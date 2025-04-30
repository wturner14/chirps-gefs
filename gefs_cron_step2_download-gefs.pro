;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GEFS_CRON_STEP2 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
;   /home/chc-source/marty/CHIRPS3-GEFS/Default/cron/get_gefs_op_v12_p25.pro                    ;
;                                                                                               ;
; Procedure/Adaptations Written: Will Turner, UCSB Climate Hazards Center, 25 April 2025        ;
;   Status:                                                                                     ;
;   [ ] : Stable, Operational                                                                   ;
;   [X] : Development (May be operational but subject to change/edits)                          ;
;   [ ] : Exploratory (Designed for command line or non-automated useage)                       ;
;-----------------------------------------------------------------------------------------------;


; ----------------------------------------------------------------
;
; GET_GEFS_OP_V12 retrieves GRIB2 GEFS operational version 12 forecast files from
; AWS S3 buckets. The first 10 days are at 0.25° resolution,
; and days 11–16 (starting at forecast hour 254) are at 0.5°.
;
; URLs pulled from:
;   0.25°:
;     https://noaa-gefs-pds.s3.amazonaws.com/gefs.20240815/00/atmos/pgrb2sp25/geavg.t00z.pgrb2s.0p25.f006
;   0.50°: 
;     https://noaa-gefs-pds.s3.amazonaws.com/gefs.20240815/00/atmos/pgrb2ap5/geavg.t00z.pgrb2a.0p50.f378
;
; Output goes to:
;   /home/GEFS/operational_v12/grib/yyyy/mm/dd/geavg.t00z.pgrb2a.0p50.f348
;
; Log written to:
;   /home/GEFS/CHIRPS3-GEFS/logs/get_gefs_op_v12.txt
;
; Example usage:
;   get_gefs_op_v12, 2024, 8, 5
;   or 
;   run across a date range with loops.
;   for yr=2025, 2025 do for mo=1, 4 do for dy=1,n_days_month(yr,mo)-1 do get_gefs_op_v12, yr, mo, dy, wait_sec=200
;
; ----------------------------------------------------------------

pro get_gefs_op_v12, year, month, day, log_output=log_output, wait_sec=wait_sec

  COMPILE_OPT IDL2  ; Enables modern IDL syntax and features

  ; Root directory for storing downloaded GRIB2 files
  download_dir_root = '/home/GEFS/operational_v12/grib/' ;mfl use this as file names are as original's

  ; Base AWS S3 URL for GEFS data
  aws_server = 'https://noaa-gefs-pds.s3.amazonaws.com/gefs.'

  ; Path to log file
  log_file = '/home/GEFS/CHIRPS3-GEFS/logs/get_gefs_op_v12.txt'

  ; -------------------------------------------------------------------
  
  ; pause execution to prevent AWS "Slow Down" error
  if keyword_set(wait_sec) then begin
    print, 'Waiting for ', wait_sec, ' seconds...', f='(/a, i0, a,/)'
    wait, wait_sec
  endif


  ; Ensure the n_days_month function is available
  resolve_routine, 'n_days_month', /is_function

  f_lun = -1  ; Default to standard output unless log_output is set
  if keyword_set(log_output) then f_lun = 1

  ; Set up the log file if requested
  if f_lun eq 1 then begin
    close, f_lun
    if file_test(log_file) then file_delete, log_file
    openw, f_lun, log_file
  endif

  ; Print log header
  printf, f_lun, 'In GET_GEFS_OP_V12 for: ', year, month, day, f='(/a, i4, "/",i02,"/",i02/)'
  print, 'Writing to log file: ', log_file
  printf, f_lun, 'Writing to log file: ', log_file
  
  ; Set up error handling
  catch, error_status
  if error_status ne 0 then begin
    printf, f_lun, 'ERROR: ' + !error_state.msg
    if f_lun eq 1 then close, f_lun
    catch, /cancel
    if keyword_set(log_output) then exit
    retall
  endif

  ; Check if the requested day is valid for the month
  n_days = n_days_month(year, month)
  printf, f_lun, day, n_days
  if day gt n_days then begin
    printf, f_lun, 'Variable Day is greater than number of days in the month. Exiting...'
    if f_lun eq 1 then close, f_lun
    return
  endif

  ; Build date string used in URL paths (e.g. 20240815/00/)
  yrmodyhr = string(year, month, day, '/00/', f='(i4, i02, i02, a)')

  ; Local output directory for GRIB files
  gefs_download_dir = string(download_dir_root, year, month, day, f='(a,i4,"/",i02,"/",i02,"/")')

  ; Create output directory if it doesn't exist
  if ~ file_test(gefs_download_dir, /dir) then begin
    printf, f_lun, 'Making directory: ' + gefs_download_dir
    file_mkdir, gefs_download_dir
  endif

  ; Set subdirectory and file prefix for both resolutions
  gefs_p25_dir = 'atmos/pgrb2sp25/'
  gefs_p25_prefix = 'geavg.t00z.pgrb2s.0p25.f'

  gefs_p5_dir = 'atmos/pgrb2ap5/'
  gefs_p5_prefix = 'geavg.t00z.pgrb2a.0p50.f'

  ; Loop through all forecast hours from 6 to 384 in steps of 6 hours
  for hr=6, 384, 6 do begin
    
    ; Use 0.25° files for hours < 246
    if hr lt 246 then begin
      gefs_file_name = string(gefs_p25_prefix, hr, f='(a,i03)')
      gefs_url_path = string(aws_server, yrmodyhr, gefs_p25_dir, gefs_file_name, f='(4a)')
    endif else begin
      ; Use 0.5° files from hour 246 onwards
      gefs_file_name = string(gefs_p5_prefix, hr, f='(a,i03)')
      gefs_url_path = string(aws_server, yrmodyhr, gefs_p5_dir, gefs_file_name, f='(4a)')
    endelse

    ; Build local filename path
    gefs_file_path = gefs_download_dir + gefs_file_name

    ; Skip file if it’s already been downloaded and it's size greater than 2MB
    printf, f_lun, 'Testing for: ', gefs_file_path, f='(/2a)'
    if file_test(gefs_file_path) then begin
      f_info = file_info(gefs_file_path)
      if f_info.size gt 2000000 then begin
        printf, f_lun, 'GRIB files already downloaded.'
        continue        
      endif
    endif

    ; Attempt to retrieve the file using wget function
    printf, f_lun, 'Retrieving: ' + gefs_url_path
    file = wget(gefs_url_path, filename=gefs_file_path)

    ; Check if the file was successfully downloaded
    if ~ file_test(gefs_file_path) then begin
      message, 'ERROR: File not retrieved: ' + gefs_file_path
    endif else begin
      printf, f_lun, 'Retrieved ', gefs_file_path
    endelse

    flush, f_lun  ; Write out log buffer
  endfor

  printf, f_lun, 'fini!'  ; All done message

  ; Close log file if opened
  if f_lun eq 1 then close, f_lun

  return
END