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
  ; idl -args YYYY MM DD [0/1] < /home/chc-source/will/crons/chirps_gefs/gefs_cron_step1.pro      ;
  ;   YYYY: Year of interest                                                                      ;
  ;   MM: Month of interest                                                                       ;
  ;   DD: Day of interest                                                                         ;
  ;   0/1: Binary option for re-run. Set to 1 to force a re-run overwrite of existing files       ;
  ;-----------------------------------------------------------------------------------------------;
  ;-----------------------------------------------------------------------------------------------;
  ; ADAPTED FROM:                                                                                 ;
  ;   /home/chc-source/marty/CHIRPS3-GEFS/Default/cron/cron_mk_gefs3_dailies_16day.pro            ;
  ;                                                                                               ;
  ; Procedure/Adaptations Written: Will Turner, UCSB Climate Hazards Center, 25 April 2025        ;
  ;   Status:                                                                                     ;
  ;   [ ] : Stable, Operational                                                                   ;
  ;   [X] : Development (May be operational but subject to change/edits)                          ;
  ;   [ ] : Exploratory (Designed for command line or non-automated useage)                       ;
  ;-----------------------------------------------------------------------------------------------;
  
  ; Append necessary directories to the system !PATH variable
  !path = !path + ':/home/chc-source/will/dump'
  !path = !path + ':/home/chc-source/will/crons/chirps_gefs'
  !path = !path + '/home/chc-source/marty/CHIRPS3-GEFS/Default/utilities:'
  !path = !path + '/home/chc-source/marty/CHIRPS3-GEFS/Default/operational:'
  
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
    printf, f_lun, SYSTIME(), ': Cron is running', f='(2a/)'  &$
    flush, f_lun  &$
    free_lun, f_lun, EXIT_STATUS=log_flag, /FORCE  &$

    ; Set up the log file
    log_file = log_dir + 'gefs_cron_log.txt'  &$
    openw, f_lun, log_file, /GET_LUN  &$
    printf, f_lun, SYSTIME(), ': BEGINNING THE GET GEFS JOB', f='(2a)'  &$
    printf, f_lun, SYSTIME(), $
      ': Using script: /home/chc-source/will/crons/chirps_gefs/gefs_cron_step1.pro', $
      f='(2a/)'  &  flush, f_lun  &$
    
    ; Get today's date
    caldat, julday(), month, day, year, hour  &$
    
    ; Allow for manual override of date via command-line arguments
    ; Flag to determine if this is a re-run (e.g., from command-line override)
    ; Default is to not re-run
    re_run = 0    &$ 
    ; check for command-line arguments
    args = COMMAND_LINE_ARGS(count=n_args)  &$
    IF n_args gt 0 THEN BEGIN  &$
      printf, f_lun, SYSTIME(), '*** WARNING Setting values from command line! ***', f='(/a)'  &$
      flush, f_lun  &$
      IF n_args eq 4 THEN BEGIN  &$
        year = FIX(args[0])  &$
        month = FIX(args[1])  &$
        day = FIX(args[2])  &$
        re_run = FIX(args[3])  &$
        IF re_run gt 0 THEN $
          printf, f_lun, SYSTIME(), ': Note: Forced re-run is ON (= 1).', f='(a,a/)'
      ENDIF ELSE BEGIN  &$
        printf, f_lun, SYSTIME(), '*** Incorrect arguments! YYYY, MM, DD, [0/1] Required ***', f='(a/)'  &$
        flush, f_lun  &$
        exit  &$
      ENDELSE  &$
    ENDIF  &$
    
    ; Log the working date
    printf, f_lun, SYSTIME(), ' : Working on forecast day: ', year, month, day, $
      f='(/a, a, i4, "-", i02, "-", i02)' &  flush, f_lun  &$
    
    ; Construct path to expected daily forecast output directory
    daily_dir = STRING(Out_Dir,year,'/',month,'/',day,'/',$
      f='(a,i4,a,i02,a,i02,a)')  &$
    printf, f_lun, SYSTIME(), ': Searching for dailies in: ' + daily_dir  &$
    
    ; Search for all expected daily TIFF output files
    daily_files = FILE_SEARCH(daily_dir + '*.tif', count=n_daily_files)  &$
    printf, f_lun, daily_files  &  flush, f_lun  &$
    printf, f_lun, 'n files: ',n_daily_files,f='(a,i0)'  &  flush, f_lun  &$
    
    ; If any files are missing or if re-run is set to 1, then continue
    IF n_daily_files lt 16 OR re_run gt 0 THEN BEGIN  &$
      IF n_daily_files lt 16 THEN $
        printf, f_lun, 'Missing files. Continuing job.' ELSE $
        printf, f_lun, 'Forced re-run is turned ON. Continuing job.'
      flush, f_lun  &$
      
      ; Before proceeding, let's copy this over to a new log file to be saved to our records
      printf, f_lun, systime(), ': Transfering to a new log file', f='(2a)'  &$
      flush, f_lun  &$
      FREE_LUN, f_lun, EXIT_STATUS=log_flag, /FORCE  &$
      curr_log_file = STRING(log_dir,'log_mm_current.txt',f='(a,a)')  &$
      SPAWN,STRING('cp ',log_file,' ',curr_log_file, f='(4a)')  &$

      openw, f_lun, curr_log_file, /GET_LUN, /APPEND  &$
      printf,f_lun, '**********************', f='(/a/)'  &$
      flush, f_lun  &$

      ; Compile necessary scripts
      ; Load procedures dynamically if not already compiled
      resolve_routine, 'gefs_cron_step2_download-gefs'  &$
      resolve_routine, 'gefs_cron_step3_make-dailies'  &$

      ; Download the GEFS data
      printf, f_lun, 'Calling GET_GEF_OP_V12, ' & flush, f_lun  &$
      get_gefs_op_v12, year, month, day, log_output=log_output  &$

      ; Process the downloaded GEFS data into daily and 16 day accumulations
      printf, f_lun, 'Calling MK_GEFS_OP_V12_DAILIES...'  & flush, f_lun  &$
      mk_gefs_op_v12_dailies_16day, year, month, day, log_output=log_output  &$

      ; Wrap up
      printf, f_lun, 'fini!'  &$
      if f_lun ne -1 then close, f_lun  &$    

    ; If all 16 daily files are found and this is not a re-run, exit early
    ENDIF ELSE BEGIN  &$
      printf, f_lun, SYSTIME(), $
        ': All daily GEFS files are available locally. Nothing further is needed.', $
        f='(a,a)' &$
    ENDIF  &$
    printf, f_lun, SYSTIME(), 'Job complete.' &  flush, f_lun  &$
    free_lun, f_lun, EXIT_STATUS=log_flag, /FORCE  &$

    ; Copy log file to the archive directory
    archive_log_file = STRING(Log_Dir,'archive/log_gefs_',y,m,d,'.txt',f='(a,a,i4.4,i2.2,i2.2,a)')  &$
    FILE_COPY,curr_log_file,archive_log_file,/OVERWRITE  &$
  ENDFOR  &$

    ; Now that the job is complete, turn the 'running flag' off
    spawn,STRING('rm -f ',cron_is_running, f='(2a)')  &$
  ENDIF ELSE BEGIN  &$
    print, 'cron is already running!'  &$
  ENDELSE


