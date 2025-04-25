;
; CRON_MK_C3G_FORECASTS_V12 
; 
; for running from the command line with arguments to force the date
; idl -args 2019 9 11 < /home/marty/IDLWorkspace80/Default/GEFS/new_version/cron_mk_cg_forecasts_v12.pro
;
; Log files:
; CRON_MK_C3G_FORECASTS_V12: /home/scratch-GEFS/logs/cron_mk_cg_forecasts_v12.txt
; MK_CHIRPS_GEFS_V12: /home/GEFS/logs/mk_chirps_gefs_v12.txt
; DISAGG_TO_DAILIES_V12: /home/GEFS/logs/disagg_to_dailies_v12.txt
; AGG_ACCUMS_FROM_DAILIES_V12: /home/GEFS/logs/agg_accums_from_dailies_v12.txt
; 
; 
; 
;-------------------------------------------------------------------------------------

gefs_daily_dir_base =  '/home/GEFS/daily_predicts_v12/'
cg_testing_dir = '/home/chc-data-out/products/EWX/data/forecasts/CHIRPS-GEFS_precip_v12/05day/precip_mean/'

log_file = '/home/GEFS/CHIRPS3-GEFS/logs/cron_mk_cg_forecasts_v12.txt'
log_output = 1
var = 'apcp_sfc'
member = ['mean']
re_run = 0

;-------------------------------------------------------------------------------------


f_lun = -1
if log_output eq 1 then f_lun=2
compile_opt IDL2 
;
; Append necessary directories to the system !PATH variable
!path = '/home/chc-source/marty/CHIRPS3-GEFS/Default/utilities:' + !path
!path = '/home/chc-source/marty/CHIRPS3-GEFS/Default/operational:' + !path

;!path += '/home/marty/IDLWorkspace80/Default/GEFS/new_version:'
;!path += '/home/marty/IDLWorkspace80/Default/GEFS/new_version/subroutines:'
;!path += '/home/marty/IDLWorkspace80/Default/GEFS/utilities:'
;!path += '/home/marty/IDLWorkspace80/Default/utilities:'
;!path += '/home/marty/IDLWorkspace80/Default/CSCD1/utilities:'
;!path += '/home/marty/IDLWorkspace80/Default/SWIM/utilities:'
;!path += '/home/source/husak/idl_functions:'
;!path += '/home/code/idl_user_contrib/chg:'
;!path += '/home/code/idl_user_contrib/esrg:'
;!path += '/home/code/idl_user_contrib/pending:' 
;!path += '/home/code/idl_user_contrib/idl_sql:'
;!path += '/home/code/idl_user_contrib/coyote:'


; --------------------------------------------------------------------


if f_lun ne -1 then close, f_lun
if f_lun ne -1 then openw, f_lun, log_file
if f_lun ne -1 then print, 'Writing to log file: ', log_file

printf, f_lun, 'Starting cron... ' & flush, f_lun


; get today's date
caldat, julday(), month, day, year

; for running from the command line with arguments to force the date
; idl -args 2019 9 11 < /home/marty/IDLWorkspace80/Default/GEFS/new_version/cron_mk_cg_forecasts_v12.pro
args = command_line_args(count=n_args)

if n_args eq 3 then begin &$
  if f_lun ne -1 then close, f_lun &$
  f_lun = -1 &$
  printf, f_lun, '*** WARNING Setting values from command line! ***', f='(/a/)' &$
  year = fix(args[0]) &$
  month = fix(args[1]) &$
  day = fix(args[2]) &$
  log_output = 0 &$
  re_run = 1 &$
endif

printf, f_lun, 'Working on forecast day: ', year, month, day, f='(/a, i4, "-", i02, "-", i02/)' & flush, f_lun

; test if accumulations already made
test_file = string(cg_testing_dir, 'data-mean_', year, month, day, '_*', f='(2a,i4,2i02,a)')
res = file_search(test_file, count=n_test_files)
printf, f_lun, 'Testing for accumulation file...', test_file
printf, f_lun, 'Found...', n_test_files, ' accumulation files'

if n_test_files eq 1 and ~ re_run then begin &$
  printf, f_lun, 'Accumulation file exist, exiting cron job...' &$
  if f_lun ne -1 then close, f_lun &$
  exit &$
endif
 
; check if dailies made
gefs_daily_dir = string(gefs_daily_dir_base, year, month, day, f='(a,i4,"/",i02,"/",i02,"/")')
printf, f_lun, 'Searching for dailies in: '+ gefs_daily_dir
daily_files = file_search(gefs_daily_dir + '*.tif', count=n_daily_files)

if n_daily_files ne 16 then begin &$
  printf, f_lun, 'Found', n_daily_files, 'daily files, exiting cron job...' &$
  if f_lun ne -1 then close, f_lun &$
  exit &$
endif

  
printf, f_lun, 'Found ', n_daily_files, ' files'

resolve_routine, 'mk_chirps3_gefs_16day'
resolve_routine, 'disagg_to_dailies_v12'
resolve_routine, 'agg_accums_from_dailies_v12'

help, /source_file, output=helper
printf, f_lun, helper

printf, f_lun, 'Calling MK_CHIRPS3_GEFS_16DAY... ' & flush, f_lun
mk_chirps3_gefs_16day, year, month, day, log_output=log_output


printf, f_lun, 'Calling DISAGG_TO_DAILIES_V12... ' & flush, f_lun
disagg_to_dailies_v12, year, month, day, 'apcp_sfc', '16day', log_output=log_output


printf, f_lun, 'Calling AGG_ACCUMS_FROM_DAILIES_V12, 05 day... ' & flush, f_lun
agg_accums_from_dailies_v12, year, month, day, '05day', log_output=log_output

printf, f_lun, 'Calling AGG_ACCUMS_FROM_DAILIES_V12, 10 day... ' & flush, f_lun
agg_accums_from_dailies_v12, year, month, day, '10day', log_output=log_output

printf, f_lun, 'Calling AGG_ACCUMS_FROM_DAILIES_V12, 15 day... ' & flush, f_lun
agg_accums_from_dailies_v12, year, month, day, '15day', log_output=log_output


printf, f_lun, 'Calling MK_CG_ANOM_ZSCORE_V12, 05 day... ' & flush, f_lun
mk_cg_anom_zscore_v12, year, month, day,'apcp_sfc', 'mean', '05day', re_run=re_run, log_output=log_output

printf, f_lun, 'Calling MK_CG_ANOM_ZSCORE_V12, 10 day... ' & flush, f_lun
mk_cg_anom_zscore_v12, year, month, day,'apcp_sfc', 'mean', '10day', re_run=re_run, log_output=log_output

printf, f_lun, 'Calling MK_CG_ANOM_ZSCORE_V12, 15 day... ' & flush, f_lun
mk_cg_anom_zscore_v12, year, month, day,'apcp_sfc', 'mean', '15day', re_run=re_run, log_output=log_output



printf, f_lun, 'Calling AGG_3_PENTADS_FROM_DAILIES_V12... ' & flush, f_lun
agg_3_pentads_from_dailies_v12, year, month, day, log_output=log_output


printf, f_lun, 'Calling MK_CG_DEKAD_FORECAST_V12... ' & flush, f_lun
mk_cg_dekad_forecast_v12, year, month, day, log_output=log_output


printf, f_lun, systime(), ':  fini!'
if f_lun ne -1 then close, f_lun



;if n_daily_files_p5 eq 16 and n_daily_files_p25 eq 10 and ~ re_run then begin &$
;  printf, f_lun, 'Found ', n_daily_files_p5, ' n_daily_files_p5 and found ', n_daily_files_p25, ' n_daily_files_p25 so exiting...', f='(a,i0,a,i0,a)' &$
;  print,         'Found ', n_daily_files_p5, ' n_daily_files_p5 and found ', n_daily_files_p25, ' n_daily_files_p25 so exiting...', f='(a,i0,a,i0,a)' &$
;  if f_lun ne -1 then close, f_lun &$
;  exit &$
;endif

;daily_dir = string('/home/scratch-GEFS/GEFS_daily_predicts_v12/', year, month, day, f='(a,i4,"/",i02,"/",i02,"/")')
;printf, f_lun, 'Searching for dailies in: ', daily_dir
;daily_files = file_search(daily_dir + '*.tif', count=daily_file_count)
;
;;if daily_file_count lt 192 then begin &$  for all members
;if daily_file_count lt 16 then begin &$
;  printf, f_lun, 'Found only ', daily_file_count, ' so exiting...', f='(a,i0,a)' &$
;  if f_lun ne -1 then close, f_lun &$
;  exit &$
;endif
;
;data_dir = '/home/chc-data-out/products/EWX/data/forecasts/CHIRPS-GEFS_precip_v12/16day/precip_mean/'
;file_name = get_geoe5_file_name('data-mean', year, month, day, '16day', /extension)
;
;if file_test(data_dir+file_name) then begin &$
;  print, 'Skipping because 16 day  file exists: ', file_name &$
;  return &$
;endif
