  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GEFS_CRON_STEP1 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;-----------------------------------------------------------------------------------------------;
  ; THIS SCRIPT DOWNLOADS 16-DAY GEFS (GLOBAL ENSEMBLE FORECAST SYSTEM) APCP_SFC FORECASTS AND    ;
  ; PROCESSES THEM INTO DAILY ACCUMULATED TIFFS FOR DOWNSTREAM USE.                               ;
  ;-----------------------------------------------------------------------------------------------;
  ;-----------------------------------------------------------------------------------------------;
  ; OUTPUT                                                                                        ;
  ;
  ;-----------------------------------------------------------------------------------------------;
  ;-----------------------------------------------------------------------------------------------;
  ; PRIMARY SCRIPTS USED                                                                          ;
  ;   GET_GEFS_OP_V12                                                                             ;
  ;     -- RETRIEVES GRIB2 FILES VIA WGET                                                         ;
  ;   MK_GEFS_OP_V12_DAILIES_16DAY                                                                ;
  ;     -- CREATES DAILY AND 16 DAY FORECAST TIFFS FROM GRIB2 FILES                               ;
  ;-----------------------------------------------------------------------------------------------;
  ;-----------------------------------------------------------------------------------------------;
  ; EXAMPLE USEAGE                                                                                ;
  ;   AS CRON JOB:                                                                                ;
  ; 38 2 * * * idl < /home/chc-source/will/crons/chirps_gefs/gefs_cron_step1.pro                  ;
  ;   FROM THE COMMAND LINE                                                                       ;
  ; idl -args 2022 2 2 < /home/chc-source/will/crons/chirps_gefs/gefs_cron_step1.pro              ;
  ;-----------------------------------------------------------------------------------------------;
  ;-----------------------------------------------------------------------------------------------;
  ;  Procedure/Adaptations Written: Will Turner, UCSB Climate Hazards Center, 25 April 2025       ;
  ;  Status:                                                                                      ;
  ;   [ ] : Stable, Operational                                                                   ;
  ;   [X] : Development (May be operational but subject to change/edits)                          ;
  ;   [ ] : Exploratory (Designed for command line or non-automated useage)                       ;
  ;-----------------------------------------------------------------------------------------------;
  
  !path = !path + ':/home/chc-source/will/dump'
  !path = !path + ':/home/chc-source/will/crons/chirps_gefs'
  
  ; Set base directory for daily outputs and log file path
  Out_Dir = '/home/GEFS/daily_precip_v12/'
  Log_Dir = STRING(Out_Dir,'logs/',f='(2a)')
  ; Make sure the cron isn't already running
  cron_is_running = STRING(Log_Dir,'gefs_cron_is_running.txt',f='(2a)')
  ; if you just need to reset the running flag
  ;  FILE_DELETE,cron_is_running,/ALLOW_NONEXISTENT
  
  IF ~FILE_TEST(cron_is_running) THEN BEGIN  &$
    ; Save the running flag file
    openw, f_lun, cron_is_running, /GET_LUN  &$
    printf, f_lun, systime(), 'Cron is running', f='(2a/)'  &$
    flush, f_lun  &$
    free_lun, f_lun, EXIT_STATUS=log_flag, /FORCE  &$

    ; Set up the log file
    log_file = log_dir + 'gefs_cron_log.txt'  &$
    openw, f_lun, log_file, /GET_LUN  &$
    printf, f_lun, systime(), ': BEGINNING THE MAKE GEFS CRON JOB', f='(2a/)'  &$
    flush, f_lun  &$
    
    log_output = 1    &$; Flag to control whether logging is enabled
    
    ; Initialize file unit for log output
    f_lun = -1  &$
    if log_output eq 1 then f_lun = 2  &$
    
    ; Use IDL2 compatibility mode (modern syntax, stricter typing, etc.)
    compile_opt IDL2  &$
    
    ; Append necessary directories to the system !PATH variable
    !path = '/home/chc-source/marty/CHIRPS3-GEFS/Default/utilities:' + !path  &$
    !path = '/home/chc-source/marty/CHIRPS3-GEFS/Default/operational:' + !path  &$
    
    ; --------------------------------------------------------------------
    
    ; Open log file if logging to non-standard output (-1) is enabled, open log file
    if f_lun ne -1 then close, f_lun  &$
    if f_lun ne -1 then openw, f_lun, log_file  &$
    if f_lun ne -1 then print, 'Writing to log file: ', log_file  &$
    
    re_run = 0    &$ ; Flag to determine if this is a re-run (e.g., from command-line override)
    
    printf, f_lun, 'f_lun = ', f_lun    &$ ; Log file unit number
    
    ; Get today's date
    caldat, julday(), month, day, year, hour  &$
    
    ; Allow for manual override of date via command-line arguments
    args = command_line_args(count=n_args)  &$
    
    if n_args ge 3 then begin &$
      if f_lun ne -1 then close, f_lun &$
      f_lun = -1 &$
      printf, f_lun, '*** WARNING Setting values from command line! ***', f='(/a/)' &$
      year = fix(args[0]) &$
      month = fix(args[1]) &$
      day = fix(args[2]) &$
      re_run = 1 &$
      log_output = 0 &$
    endif  &$
    
    ; Log the working date
    printf, f_lun, 'Working on forecast day: ', year, month, day, $
      f='(/a, i4, "-", i02, "-", i02/)' & flush, f_lun  &$
    printf, f_lun, 'log_output = ', log_output  &$
    printf, f_lun, '!path = ', !path  &$
    
    ; Construct path to expected daily forecast output directory
    daily_dir = string(Out_Dir, year, month, day, f='(a,i4,"/",i02,"/",i02,"/")')  &$
    printf, f_lun, 'Searching for dailies in: ' + daily_dir  &$
    
    ; Search for all expected daily TIFF output files
    daily_files = file_search(daily_dir + '*.tif', count=n_daily_files)  &$
    
    ; If all 16 daily files are found and this is not a re-run, exit early
    if n_daily_files eq 16 and ~re_run then begin &$
      printf, f_lun, 'Found all daily GEFS files so exiting...', f='(a,i0,a)' &$
      print, 'Found all daily GEFS files so exiting...', f='(/a/)' &$
      if f_lun ne -1 then close, f_lun &$
      exit &$
    endif  &$
    printf, f_lun, 'Not all daily GEFS files found...', f='(a,i0,a)'  &$
    
    ; Load procedures dynamically if not already compiled
    resolve_routine, 'get_gefs_op_v12_p25'  &$
    resolve_routine, 'mk_gefs_op_v12_dailies'  &$
    
    ; Download the GEFS data
    printf, f_lun, 'Calling GET_GEF_OP_V12, ' & flush, f_lun  &$
    get_gefs_op_v12, year, month, day, log_output=log_output  &$
    
    ; Process the downloaded GEFS data into daily and 16 day accumulations
    printf, f_lun, 'Calling MK_GEFS_OP_V12_DAILIES...'  & flush, f_lun  &$
    mk_gefs_op_v12_dailies_16day, year, month, day, log_output=log_output  &$
    
    ; Wrap up
    printf, f_lun, 'fini!'  &$
    if f_lun ne -1 then close, f_lun  &$
  ENDIF ELSE BEGIN  &$
    print, 'cron is already running!'  &$
  ENDELSE


