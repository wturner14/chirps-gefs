PRO CRON_2_CHIRPSGEFS_GLBL_GRAPHICS, Out_Dir, Log_Dir, f_lun
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
  ;-----------------------------------------------------------------------------------------------;

  log_dir = '/home/chc-source/will/crons/chirps_gefs/logfiles/'

  ;;; SET UP THE LOG FILE
  printf, f_lun, systime(), ': BEGINNING THE CHIRPS-GEFS GLOBAL GRAPHICS PROCEDURE', f='(/2a/)'
  flush, f_lun

  countries_shp = '/home/chc-source/will/code/user_contrib/GAUL/GAUL_2013/G2013_2012_0.shp'
  glbl_admin1_shp = '/home/chc-source/will/code/user_contrib/GAUL/GAUL_2008/global/g2008_1.shp'
  afr_admin1_shp = '/home/chc-source/will/code/user_contrib/GAUL/GAUL_2019/Africa/g2019_af_1.shp'
;  glbl_admin1_shp = '/home/marty/GAUL/global/g2008_1.shp'
;  afr_admin1_shp = '/home/marty/GAUL_2019/Africa/g2019_af_1.shp'
;  admin1_shp = '/home/chg-laura/shapefiles/FEWSNET_World_Admin/FEWSNET_Admin1.shp'
  mo_str = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
  
  accum_periods = [5,10,15]
  n_ap = N_ELEMENTS(accum_periods)
  data_type = ['precip','anom']
  n_dt = N_ELEMENTS(data_type)

  ; Before proceeding, check to see if this is new data
  IF FILE_TEST(STRING(Log_Dir,'last_precip_max.sav',f='(2a)')) THEN BEGIN
    RESTORE,STRING(Log_Dir,'last_precip_max.sav',f='(2a)')
    old_max = current_precip_max
  ENDIF ELSE old_max = 0.

  ; Read in all of the most recent data files
  printf, f_lun, systime(), ': data file name', f='(/2a/)'  & flush, f_lun
  Current_Data_Max = FLTARR(n_ap*n_dt)
  FOR ap=0,n_ap-1 DO BEGIN
    FOR dt=0,n_dt-1 DO BEGIN
      dir = STRING('/home/chc-data-out/products/EWX/data/forecasts/CHIRPS-GEFS_precip_v12/',$
        accum_periods[ap],'day/',data_type[dt],'_mean/',f='(a,I2.2,a,a,a)')
      cg_fnames = FILE_SEARCH(STRING(dir,'*.tif',f='(2a)'),COUNT=nfiles)
      fname = cg_fnames[-1]
      cg_data = READ_TIFF(fname,GEOTIFF=GTag)
      Current_Data_Max[(ap*2)+dt] = MAX(cg_data)
      printf, f_lun, systime(), ': ', fname, f='(3a)'
    ENDFOR
  ENDFOR
  flush, f_lun
  current_precip_max = TOTAL(Current_Data_Max)

  ; If the max value is different from the last run, then we know that we have new data
  IF current_precip_max ne old_max THEN BEGIN
    
    ;;; WE HAVE NEW DATA! PROCEED WITH GRAPHIC PRODUCTION    
    ;Set the current precip max as the new 'Last Precip Max' to be compared to next time
    SAVE,current_precip_max,$
      FILENAME=STRING(Log_Dir,'last_precip_max.sav',f='(2a)')
    printf, f_lun, systime(), ': NEW DATA IS AVAILABLE', f='(/2a)' & flush, f_lun
    printf, f_lun, systime(), ': Saved new precip max variable', f='(2a/)' & flush, f_lun
    printf, f_lun, systime(), ': Closing this file. Beginning graphics production', f='(2a/)'
    flush, f_lun
    FREE_LUN, f_lun

    ; Organize geotag info
    NX = (SIZE(cg_data))[1] & NY = (SIZE(cg_data))[2]
    res = GTag.(0)[0]
    lon_min = GTag.(1)[3]
    lon_max = lon_min + (res * (NX-1)) +res
    lat_max = GTag.(1)[4]
    lat_min = lat_max - (res * (NY-1)) -res
    map_lim = [lat_min,lon_min,lat_max,lon_max]

    ;;; SET UP A NEW LOG FILE TO BE SAVED ONLY WHEN ANALYSES ARE ACTUALLY RUN
    mons = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
    curr_date = STRSPLIT(SYSTIME(),/EXTRACT)
    start_year = FIX(curr_date[-1])
    start_month = WHERE(curr_date[1] eq mons)+1
    start_day = FIX(curr_date[2])

    ; we'll save log files for the current month. Remove the previous month's log files -- added 11/2/2021
    IF Start_Month gt 1 THEN prev_mon = Start_Month-1 ELSE prev_mon = 12
    SPAWN,STRING('rm -f ',log_dir,'log_rmm_????',prev_mon,'??.txt ',f='(a,a,a,I2.2,a)')
    
    ; save new log file
    log_file = STRING(log_dir,'log_rmm_',start_year,start_month,start_day,'.txt',f='(a,a,I4.4,I2.2,I2.2,a)')
    SPAWN,STRING('cp ',log_dir,'log_rmm.txt ',log_file, f='(4a)')
    openw, f_lun_2, log_file, /GET_LUN, /APPEND
    printf,f_lun_2, '**********************', f='(/a/)' & flush, f_lun_2
    printf, f_lun_2, systime(), ': BEGINNING THE GRAPHICS PRODUCTION', f='(2a/)'
    flush, f_lun_2
  

    ; Make maps of the the data and anomaly for each of the accumulation periods (5-, 10-, and 15-day)
    WM = 1/4.
    l_m = 43  &  b_m = 75   & r_m = 25   & t_m = 45
    w = WINDOW(DIMENSIONS=[(NX*WM)+l_m+r_m,(NY*WM)+b_m+t_m],/DEVICE,/BUFFER)
    
    FOR ap=0,n_ap-1 DO BEGIN
      printf, f_lun_2, systime(), $
        STRING(': Began the ',accum_periods[ap],'-day total forecast graphics', f='(a,I0,a)'), f='(2a)'
      flush, f_lun_2
     
      cg_fnames = FILE_SEARCH($
        STRING('/home/chc-data-out/products/EWX/data/forecasts/CHIRPS-GEFS_precip_v12/',accum_periods[ap],$
          'day/precip_mean/*.tif',f='(a,I2.2,a)'),COUNT=nfiles)
      fname = cg_fnames[-1]
      cg_data = READ_TIFF(fname)
          
      ; get the accumulation period info
      accum_string = STRSPLIT(FILE_BASENAME(fname,'.tif'),'_',/EXTRACT)
      accum_period = accum_periods[ap]
      start_year = FIX(STRMID(accum_string[1],0,4))
      start_month = FIX(STRMID(accum_string[1],4,2))
      start_day = FIX(STRMID(accum_string[1],6,2))
      end_year = FIX(STRMID(accum_string[2],0,4))
      end_month = FIX(STRMID(accum_string[2],4,2))
      end_day = FIX(STRMID(accum_string[2],6,2))
      
      ;;; MAP THE TOTAL PRECIP
      TITLE = STRING('CHIRPS-GEFS ',accum_periods[ap],'-Day Total Rainfall (mm)',f='(a,I0,a)')
      SUBTITLE = STRING('Period: ',start_day,mo_str[start_month-1],start_year,' - ',$
        end_day,mo_str[end_month-1],end_year,f='(a,I2.2,a,I4.4,a,I2.2,a,I4.4)')
              
      ; set up colortable (based on NOAA CPC Graphics)
      ct_dump = noaa_ppt_total_cmap(cg_data)
      index = ct_dump.index
      colors = ct_dump.colors

      m1 = MAP('Geographic',LIMIT=map_lim,MARGIN=[l_m,b_m,r_m,t_m],/DEVICE,/CURRENT,/HIDE)
      tmpgr = CONTOUR(REVERSE(cg_data,2),$
        FINDGEN(NX)*(res) + lon_min, FINDGEN(NY)*(res) + lat_min,$
        /FILL, ASPECT_RATIO=1, C_VALUE=index, C_COLOR=colors,  $
        MAP_PROJECTION='Geographic', XSTYLE=1, YSTYLE=1, /OVERPLOT, FONT_SIZE=10)
      tmpgr.mapgrid.linestyle = 6 & tmpgr.mapgrid.label_position = 0
      tmpgr.mapgrid.label_angle = 0 & tmpgr.mapgrid.font_size = 10
      tp = tmpgr.position
      
      mc = MAPCONTINENTS(countries_shp, $
        /COUNTRIES, COLOR='black',THICK=1,FILL_BACKGROUND=0,/CLIP)
      
      ;Put a box outline around the plot
      bxs = [lon_min,lon_max,lon_max,lon_min,lon_min]
      bys = [lat_min,lat_min,lat_max,lat_max,lat_min]
      outlin = PLOT(bxs,bys,THICK=3,color='black',/OVERPLOT,CLIP=0)
      
      ;Add titles
      grtitle = TEXT(0.5,tp[3]+0.039,TITLE,ALIGNMENT=0.5,FONT_SIZE=16)
      grsubtitle = TEXT(0.5,tp[3]+0.008,SUBTITLE,ALIGNMENT=0.5,FONT_SIZE=11)
      
      ;Add a colorbar
      cb = colorbar(RGB_TABLE=REFORM(colors[*,1:-1]), $
        POSITION=[tp[0]+0.0425,tp[1]-0.085,tp[2]-0.0425,tp[1]-0.045], $
        TICKNAME=STRING(FIX(index[2:-2]),f='(I0.4)'), $
        TICKVALUES=INDGEN(N_ELEMENTS(index)-3)+1,$
        FONT_SIZE=13, THICK=2,TICKLAYOUT=0,TICKLEN=1,MINOR=0,TAPER=0,/BORDER)
      
      ;Save as png (overwrite existing latest images)
      gname = STRING(Out_Dir,'TotalPrecip_',accum_periods[ap],'day_latest.png',f='(a,a,I2.2,a)')
      tmpgr.SAVE,gname
      ; make a copy for the archive
      aname = STRING(Out_Dir,'archive/TotalPrecip_',accum_periods[ap],'day_',start_year,start_month,start_day,'.png',$
        f='(a,a,I2.2,a,I4.4,I2.2,I2.2,a)')
      SPAWN,STRING('cp -f ',gname,' ',aname,f='(4a)')
      tmpgr.erase
      
      printf, f_lun_2, systime(), $
        STRING(': Finished the ',accum_periods[ap],'-day total forecast graphics', f='(a,I0,a)'), f='(2a/)'
      flush, f_lun_2    
    ENDFOR

    FOR ap=0,n_ap-1 DO BEGIN
      printf, f_lun_2, systime(), $
        STRING(': Began the ',accum_periods[ap],'-day anomaly forecast graphics', f='(a,I0,a)'), f='(2a)'
      flush, f_lun_2

      ;;; MAP THE ANOMALY
      cg_fnames = FILE_SEARCH($
        STRING('/home/chc-data-out/products/EWX/data/forecasts/CHIRPS-GEFS_precip_v12/',accum_periods[ap],$
        'day/anom_mean/*.tif',f='(a,I2.2,a)'),COUNT=nfiles)
      fname = cg_fnames[-1]
      cg_data = READ_TIFF(fname)

      ; get the accumulation period info
      accum_string = STRSPLIT(FILE_BASENAME(fname,'.tif'),'_',/EXTRACT)
      start_year = FIX(STRMID(accum_string[1],0,4))
      start_month = FIX(STRMID(accum_string[1],4,2))
      start_day = FIX(STRMID(accum_string[1],6,2))
      end_year = FIX(STRMID(accum_string[2],0,4))
      end_month = FIX(STRMID(accum_string[2],4,2))
      end_day = FIX(STRMID(accum_string[2],6,2))

      TITLE = STRING('CHIRPS-GEFS ',accum_periods[ap],'-Day Total Rainfall Anomaly (mm)',f='(a,I0,a)')
      SUBTITLE = STRING('Period: ',start_day,mo_str[start_month-1],start_year,' - ',$
        end_day,mo_str[end_month-1],end_year,f='(a,I2.2,a,I4.4,a,I2.2,a,I4.4)')

      ; set up colortable (based on NOAA CPC Graphics)
      ct_dump = noaa_ppt_anomaly_cmap(cg_data)
      index = ct_dump.index
      colors = ct_dump.colors

      m1 = MAP('Geographic',LIMIT=map_lim,MARGIN=[l_m,b_m,r_m,t_m],/DEVICE,/CURRENT,/HIDE)
      tmpgr = CONTOUR(REVERSE(cg_data,2),$
        FINDGEN(NX)*(res) + lon_min, FINDGEN(NY)*(res) + lat_min,$
        /FILL, ASPECT_RATIO=1, C_VALUE=index, C_COLOR=colors,  $
        MAP_PROJECTION='Geographic', XSTYLE=1, YSTYLE=1, /OVERPLOT, FONT_SIZE=10)
      tmpgr.mapgrid.linestyle = 6 & tmpgr.mapgrid.label_position = 0
      tmpgr.mapgrid.label_angle = 0 & tmpgr.mapgrid.font_size = 10
      tp = tmpgr.position

      mc = MAPCONTINENTS(countries_shp, $
        /COUNTRIES, COLOR='black',THICK=1,FILL_BACKGROUND=0,/CLIP)

      ;Put a box outline around the plot
      bxs = [lon_min,lon_max,lon_max,lon_min,lon_min]
      bys = [lat_min,lat_min,lat_max,lat_max,lat_min]
      outlin = PLOT(bxs,bys,THICK=3,color='black',/OVERPLOT,CLIP=0)

      ;Add titles
      grtitle = TEXT(0.5,tp[3]+0.039,TITLE,ALIGNMENT=0.5,FONT_SIZE=16)
      grsubtitle = TEXT(0.5,tp[3]+0.008,SUBTITLE,ALIGNMENT=0.5,FONT_SIZE=11)

      ;Add a colorbar
      cb = colorbar(RGB_TABLE=colors, $
        POSITION=[tp[0]+0.0425,tp[1]-0.085,tp[2]-0.0425,tp[1]-0.045], $
        TICKNAME=STRING(FIX(index[1:-2]),f='(I0.4)'), $
        TICKVALUES=INDGEN(N_ELEMENTS(index)-2)+1,$
        FONT_SIZE=13, THICK=2,TICKLAYOUT=0,TICKLEN=1,MINOR=0,TAPER=0,/BORDER)

      ;Save as png (overwrite existing latest images)
      gname = STRING(Out_Dir,'Anomaly_',accum_periods[ap],'day_latest.png',f='(a,a,I2.2,a)')
      tmpgr.SAVE,gname
      ; make a copy for the archive
      aname = STRING(Out_Dir,'archive/Anomaly_',accum_periods[ap],'day_',start_year,start_month,start_day,'.png',$
        f='(a,a,I2.2,a,I4.4,I2.2,I2.2,a)')
      SPAWN,STRING('cp -f ',gname,' ',aname,f='(4a)')
      tmpgr.erase

      printf, f_lun_2, systime(), $
        STRING(': Finished the ',accum_periods[ap],'-day anomaly forecast graphics', f='(a,I0,a)'), f='(2a/)'
      flush, f_lun_2
    ENDFOR

    printf, f_lun_2, systime(), ': CHIRPS-GEFS GLOBAL GRAPHICS CRON JOB IS COMPLETE', f='(/2a/)' & flush, f_lun
    FREE_LUN, f_lun_2
    
  ENDIF ELSE BEGIN
    printf, f_lun, systime(),': NO NEW DATA. No graphics produced.', f='(2a)' & flush, f_lun
    FREE_LUN, f_lun
    running_flag = 0
    SAVE,running_flag,FILENAME=STRING(Log_Dir,'running_flag.sav',f='(2a)')
  ENDELSE
END
