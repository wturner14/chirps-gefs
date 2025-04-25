  ;;;;;;;;;;;;;;;;;;;;;;;;;;;CHIRPS-GEFS GLOBAL GRAPHICS CRON (RUN 'EM);;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;-----------------------------------------------------------------------------------------------;
  ;THIS PROCEDURE WILL CREATE GLOBAL IMAGES (DATA AND ANOMALY) OF THE MOST UP-TO-DATE CHIRPS GEFS ;
  ;5-, 10-, AND 15-DAY FORECASTS, WHICH ARE UPDATED DAILY.                                        ;
  ;-----------------------------------------------------------------------------------------------;
  ;INPUTS                                                                                         ;
  ;  Out-Dir: [STRING directory for the output graphics]                                          ;
  ;-----------------------------------------------------------------------------------------------;
  ;OUTPUT                                                                                         ;
  ;  Writes out:                                                                                  ;
  ;     -- 0.05 degree resolution pngs of the Total and Anomaly forecasted precipitation for the  ;
  ;         designated intervals (5-, 10-, and 15-day forecast) using color tables matching those ;
  ;         used on the NOAA Climate Prediction Center                                            ;
  ;  Procedure Written: Will Turner, UCSB Climate Hazards Group, 26 July 2019                     ;
  ;  -- Updated to remove running flag because of recurrent issues. 03 January 2023               ;
  ;-----------------------------------------------------------------------------------------------;
  
  Out_Dir = '/home/chc-data-out/products/EWX/data/forecasts/CHIRPS-GEFS_precip_v12/latest_images/'
  Log_Dir = '/home/chc-source/will/crons/chirps_gefs/logfiles/'
  
  ;;;FOR DEBUGGING, RESET THE PRECIP MAX FILE
;  current_precip_max = 0.
;  SAVE,current_precip_max,FILENAME=STRING(Log_Dir,'last_precip_max.sav',f='(2a)')

  ; For the main CHIRPS-GEFS graphics worksheet
  ; For making NOAA CPC colortables
  !path = !path + ':/home/chc-source/will/dump'
  RESOLVE_ROUTINE, 'noaa_ppt_total_cmap', /IS_FUNCTION, /COMPILE_FULL_FILE, /NO_RECOMPILE, /QUIET
  RESOLVE_ROUTINE, 'noaa_ppt_anomaly_cmap', /IS_FUNCTION, /COMPILE_FULL_FILE, /NO_RECOMPILE, /QUIET
  !path = !path + ':/home/chc-source/will/crons/chirps_gefs'
  RESOLVE_ROUTINE, 'cron_2_chirpsgefs_glbl_graphics', $
    /EITHER, /COMPILE_FULL_FILE, /QUIET

  ; set up the log file
  log_file = log_dir + 'log_rmm.txt'
  openw, f_lun, log_file, /GET_LUN
  flush, f_lun

  ;;; RUN IT!
  printf, f_lun, systime(), $
    ': BEGINNING THE CHIRPS-GEFS GLOBAL GRAPHICS CRON JOB', f='(2a/)'
  cron_2_chirpsgefs_glbl_graphics, Out_Dir, Log_Dir, f_lun
