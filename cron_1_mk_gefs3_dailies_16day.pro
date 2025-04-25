; -------------------------------------------------------------------------
;
; CRON_MK_GEFS3_DAILIES_16DAY
;
; This script downloads 16-day GEFS (Global Ensemble Forecast System) APCP_SFC forecasts
; and processes them into daily accumulated TIFFs for downstream use.
;
; Uses GET_GEFS_OP_V12 (retrieves GRIB2 files via wget)
; and MK_GEFS_OP_V12_DAILIES_16DAY (creates daily and 16 day forecast TIFFs from GRIB2 files).
;
; Example usage as cron job:
; 38 2 * * * idl < /home/chc-source/marty/CHIRPS3-GEFS/Default/cron/cron_mk_gefs3_dailies_16day.pro;
; or from the command line
; idl -args 2022 2 2 < /home/chc-source/marty/CHIRPS3-GEFS/Default/cron/cron_mk_gefs3_dailies_16day.pro;
; 
; -------------------------------------------------------------------------

; Set base directory for daily outputs and log file path
daily_base_dir = '/home/GEFS/daily_precip_v12/'
log_file = '/home/GEFS/logs/cron_mk_gefs3_dailies_v12.txt'

log_output = 1  ; Flag to control whether logging is enabled

; Initialize file unit for log output
f_lun = -1
if log_output eq 1 then f_lun = 2

; Use IDL2 compatibility mode (modern syntax, stricter typing, etc.)
compile_opt IDL2

; Append necessary directories to the system !PATH variable
!path = '/home/chc-source/marty/CHIRPS3-GEFS/Default/utilities:' + !path
!path = '/home/chc-source/marty/CHIRPS3-GEFS/Default/operational:' + !path

; --------------------------------------------------------------------

; Open log file if logging to non-standard output (-1) is enabled, open log file
if f_lun ne -1 then close, f_lun
if f_lun ne -1 then openw, f_lun, log_file
if f_lun ne -1 then print, 'Writing to log file: ', log_file

re_run = 0  ; Flag to determine if this is a re-run (e.g., from command-line override)

printf, f_lun, 'f_lun = ', f_lun  ; Log file unit number

; Get today's date
caldat, julday(), month, day, year, hour

; Allow for manual override of date via command-line arguments
args = command_line_args(count=n_args)

if n_args ge 3 then begin &$
  if f_lun ne -1 then close, f_lun &$
  f_lun = -1 &$
  printf, f_lun, '*** WARNING Setting values from command line! ***', f='(/a/)' &$
  year = fix(args[0]) &$
  month = fix(args[1]) &$
  day = fix(args[2]) &$
  re_run = 1 &$
  log_output = 0 &$
endif

; Log the working date
printf, f_lun, 'Working on forecast day: ', year, month, day, $
  f='(/a, i4, "-", i02, "-", i02/)' & flush, f_lun
printf, f_lun, 'log_output = ', log_output
printf, f_lun, '!path = ', !path

; Construct path to expected daily forecast output directory
daily_dir = string(daily_base_dir, year, month, day, f='(a,i4,"/",i02,"/",i02,"/")')
printf, f_lun, 'Searching for dailies in: ' + daily_dir

; Search for all expected daily TIFF output files
daily_files = file_search(daily_dir + '*.tif', count=n_daily_files)

; If all 16 daily files are found and this is not a re-run, exit early
if n_daily_files eq 16 and ~re_run then begin &$
  printf, f_lun, 'Found all daily GEFS files so exiting...', f='(a,i0,a)' &$
  print, 'Found all daily GEFS files so exiting...', f='(/a/)' &$
  if f_lun ne -1 then close, f_lun &$
  exit &$
endif
printf, f_lun, 'Not all daily GEFS files found...', f='(a,i0,a)'

; Load procedures dynamically if not already compiled
resolve_routine, 'get_gefs_op_v12_p25'
resolve_routine, 'mk_gefs_op_v12_dailies'

; Download the GEFS data
printf, f_lun, 'Calling GET_GEF_OP_V12, ' & flush, f_lun
get_gefs_op_v12, year, month, day, log_output=log_output

; Process the downloaded GEFS data into daily and 16 day accumulations
printf, f_lun, 'Calling MK_GEFS_OP_V12_DAILIES...'  & flush, f_lun
mk_gefs_op_v12_dailies_16day, year, month, day, log_output=log_output

; Wrap up
printf, f_lun, 'fini!'
if f_lun ne -1 then close, f_lun