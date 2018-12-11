;ImageQC - quality control of medical images
;Copyright (C) 2018  Ellen Wasbo, Stavanger University Hospital, Norway
;ellen@wasbo.no
;
;This program is free software; you can redistribute it and/or
;modify it under the terms of the GNU General Public License version 2
;as published by the Free Software Foundation.
;
;This program is distributed in the hope that it will be useful,
;but WITHOUT ANY WARRANTY; without even the implied warranty of
;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;GNU General Public License for more details.
;
;You should have received a copy of the GNU General Public License
;along with this program; if not, write to the Free Software
;Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


pro autoTempRun, thisTemp

  COMPILE_OPT hidden
  COMMON VARI
  RESTORE, thisPath+'data\config.dat'

  ;set parameterset
  configName=thisTemp.paramSet
  tnamesConfigS=TAG_NAMES(configS)
  tagno=WHERE(STRUPCASE(tnamesConfigS) EQ STRUPCASE(configName))
  IF tagno(0) NE -1 THEN refreshParam, configS.(tagno(0)), configName ELSE sv=DIALOG_MESSAGE('Did not find the saved parameterset-name in list of parametersets.',DIALOG_PARENT=evTop)

  ;find images in path
  IF thisTemp.path NE '' THEN BEGIN
    WIDGET_CONTROL, /HOURGLASS
    WIDGET_CONTROL, btnAppend, SET_BUTTON=0
    clearAll
    adr=thisTemp.path
    adrTempTemp=''
    
    ;ensure path ending with separator
    IF STRMID(adr(0), 0, /REVERSE_OFFSET) NE PATH_SEP(SEARCH_PATH=adr(0)) THEN adr=adr(0)+PATH_SEP(SEARCH_PATH=adr(0))

    IF thisTemp.includeSub THEN Spawn, 'dir '  + '"'+adr(0)+'"' + '*'+ '/b /s', adrTempTemp ELSE BEGIN
      Spawn, 'dir '  + '"'+adr(0)+'"' + '*'+ '/b /a-D', adrTempTemp
      adrTempTemp=adr(0)+adrTempTemp
    ENDELSE

    IF adrTempTemp(0) NE '' THEN BEGIN
      dcmAdr=!Null
      delAdr=!Null
      nFound=N_ELEMENTS(adrTempTemp)
      dcmOk=INTARR(nFound)
      ;IF adrTempTemp(0) NE '' THEN BEGIN

        WIDGET_CONTROL, lblProgress, SET_VALUE='Checking for Dicom files in specified path'
        WIDGET_CONTROL, /HOURGLASS
        FOR d=0, nFound-1 DO BEGIN

          IF FILE_BASENAME(adrTempTemp(d)) EQ 'DICOMDIR' THEN BEGIN
            dcmOk(d)=0 ; IDL crash if QUERY_DICOM on DICOMDIR - unknown reason
          ENDIF ELSE BEGIN
            fi=FILE_INFO(adrTempTemp(d))
            IF fi.directory NE 1 AND fi.exists THEN dcmOk(d)=QUERY_DICOM(adrTempTemp(d))
          ENDELSE

        ENDFOR

        dcmOkId=WHERE(dcmOk EQ 1)
        dcmNotOkId=WHERE(dcmOk EQ 0)
        IF dcmNotOkID(0) NE -1 THEN delAdr=adrTempTemp(dcmNotOkId)
        IF dcmOkId(0) NE -1 THEN dcmAdr=adrTempTemp(dcmOkId)
      ;ENDIF

      nFiles=N_ELEMENTS(dcmAdr)
      IF nFiles GT 0 THEN BEGIN
        ;last date only?
        IF thisTemp.loadBy EQ 1 THEN BEGIN
          dateList=!Null
          FOR i=0, N_ELEMENTS(dcmAdr)-1 DO BEGIN
            fileStat=FILE_INFO(dcmAdr(i));after v8.5.1 use FILE_MODTIME
            mtime=SYSTIME(0, fileStat.MTIME)
            mtimeArr=STRSPLIT(mtime, ' ', /EXTRACT)
            mtime=mtimeArr(4)+mtimeArr(1)+mtimeArr(2);yearMonDD
            dateList=[dateList,mtime]
          ENDFOR
          sortOrder=SORT(dateList)
          sortedList=dateList(sortOrder)
          dcmAdr=dcmAdr(sortOrder)
          lastDate=WHERE(sortedList EQ sortedList(-1))
          dcmAdr=dcmAdr(lastDate)
        ENDIF

        IF N_ELEMENTS(dcmAdr) GT 0 THEN BEGIN
          WIDGET_CONTROL, /HOURGLASS
          openFiles, dcmAdr, SILENT=1

          WIDGET_CONTROL, /HOURGLASS
          nImg=N_TAGS(structImgs)

          ;sort by
          IF thisTemp.sortBy(0) NE '' THEN BEGIN

            tnames=TAG_NAMES(structImgs.(0))
            sortNames=thisTemp.sortBy

            keyArr=STRARR(nIMG,9);max 9 sorting levels

            FOR ss=0, N_ELEMENTS(sortNames)-1 DO BEGIN; for each tag to sort by
              WIDGET_CONTROL, lblProgress, SET_VALUE='Sorting images: '+STRING(ss*100./N_ELEMENTS(sortNames), FORMAT='(i0)')+' %'
              tagno=WHERE(tnames EQ STRUPCASE(thisTemp.sortBy(ss)))
              IF tagno(0) NE -1 THEN BEGIN
                list2sort=!Null
                FOR i=0, nImg-1 DO list2sort=[list2sort,structImgs.(i).(tagno(0))(0)]
                reformatNo=WHERE(STRUPCASE(imgStructInfo[0,*]) EQ STRUPCASE(thisTemp.sortBy(ss)))
                IF reformatNo(0) NE -1 THEN newFormat=imgStructInfo[1,reformatNo(0)] ELSE newFormat='STRING'
                CASE newFormat OF
                  'FLOAT':list2sort=STRING(FLOAT(list2sort)-MIN(FLOAT(list2sort)), FORMAT='(f015.5)')
                  'DOUBLE':list2sort=STRING(DOUBLE(list2sort)-MIN(DOUBLE(list2sort)), FORMAT='(f025.5)')
                  'LONG':list2sort=STRING(LONG(list2sort)-MIN(LONG(list2sort)), FORMAT='(i016)')
                  ELSE:
                ENDCASE
                keyArr[*,ss]=list2sort
              ENDIF
            ENDFOR
            WIDGET_CONTROL, lblProgress, SET_VALUE=''

            newOrder=MULTISORT(keyArr[*,0],keyArr[*,1],keyArr[*,2],keyArr[*,3],keyArr[*,4],keyArr[*,5],keyArr[*,6],keyArr[*,7],keyArr[*,8])

            IF ARRAY_EQUAL(newOrder,INDGEN(nImg)) EQ 0 THEN structImgs=reorderStructStruct(structImgs, newOrder)
          ENDIF

          ;sort on acqdate
          firstImg=0
          lastImg=nImg-1
          list2sort=!Null
          FOR i=0, nImg-1 DO list2sort=[list2sort,structImgs.(i).acqDate]
          newOrder=BSORT(list2sort);bsort stable sort - not rearranging if not necessary
          IF ARRAY_EQUAL(newOrder,INDGEN(nImg)) EQ 0 THEN structImgs=reorderStructStruct(structImgs, newOrder)
          dates=list2sort(newOrder)
          dateList=dates(UNIQ(dates))

          structImgsAll=structImgs
          structImgs=CREATE_STRUCT('empty',0)

          ;set quickTemp
          qtName=thisTemp.quickTemp
          qtNumb=0
          IF qtName NE '' THEN BEGIN
            tnamesQT=TAG_NAMES(quickTemp)
            tagno=WHERE(STRUPCASE(tnamesQT) EQ STRUPCASE(qtName))
            IF tagno(0) NE -1 THEN BEGIN
              fillQuickTempList, quickTemp, SELECT_NAME=qtName;pro in refreshParam.pro
              qtNumb=tagno(0)
              WIDGET_CONTROL, btnUseMulti, SET_BUTTON=1
            ENDIF ELSE sv=DIALOG_MESSAGE('Did not find the saved quickTemp-name in list of quickTemps.',DIALOG_PARENT=evTop)
          ENDIF

          IF qtNumb EQ 0 THEN dateList=-1

          oldCopyHeader=copyHeader
          oldTransposeTable=transposeTable
          infoLogg=''
          notMove=-1
          FOR q=0, N_ELEMENTS(dateList)-1 DO BEGIN

            IF datelist(q) NE '' THEN BEGIN

              IF N_ELEMENTS(dateList) NE 1 THEN BEGIN
                notIds=WHERE(dates NE dateList(q))
                WIDGET_CONTROL, lblProgress, SET_VALUE='Getting ready for analysis of images of date '+STRING(q+1, FORMAT='(i0)')+' / ' + STRING(N_ELEMENTS(dateList), FORMAT='(i0)')
                allIds=INDGEN(nImg)
                remIds=allIds(notIds)
                structImgs=removeIDstructstruct(structImgsAll,remIds)
              ENDIF ELSE BEGIN
                structImgs=structImgsAll
                structImgsAll=!Null
              ENDELSE

              WIDGET_CONTROL, lblProgress, SET_VALUE=''
              activeImg=readImg(structImgs.(0).filename, structImgs.(0).frameNo)
              fileList=getListOpenFiles(structImgs,0,marked, markedMulti)
              WIDGET_CONTROL, listFiles, YSIZE=n_elements(fileList), SET_VALUE=fileList, SET_LIST_SELECT=0, SET_LIST_TOP=0
              WIDGET_CONTROL, listFiles, SCR_YSIZE=170
              WIDGET_CONTROL, lblLoadedN, SET_VALUE=STRING(n_elements(fileList), FORMAT='(i0)')+' )'
              clearRes
              updateInfo

              IF qtNumb NE 0 THEN BEGIN
                updateMulti
                tags=TAG_NAMES(structImgs)
                IF tags(0) NE 'EMPTY' THEN BEGIN
                  calculateQuickTest
                  IF TOTAL(results) GT 0 THEN BEGIN

                    writtenToFile=0
                    errFile=0
                    ;append resultfile?
                    IF thisTemp.pathApp NE '' THEN BEGIN
                      transposeTable=1

                      ;file exists?
                      testResFile=FILE_INFO(thisTemp.pathApp)
                      IF testResFile.exists THEN BEGIN
                        IF testResFile.SIZE EQ 0 THEN copyHeader=1 ELSE copyHeader=0
                        exportMulti

                        OPENW, resfile, thisTemp.pathApp, /APPEND, /GET_LUN
                        PRINTF, resfile, CLIPBOARD.GET()
                        CLOSE, resfile & FREE_LUN, resfile
                        writtenToFile=1
                        infoLogg=infoLogg+'Written results for date '+structImgs.(0).acqDate+' to file '+thisTemp.pathApp+newline
                      ENDIF ELSE errFile=1

                    ENDIF ELSE exportMulti

                    IF writtenToFile EQ 0 THEN BEGIN
                      IF errFile EQ 1 THEN sv=DIALOG_MESSAGE('Could not find file '+thisTemp.pathApp+newline+'Press OK to continue when current results (in clipboard) are pasted to a result file or ignored.', DIALOG_PARENT=evTop)
                      IF thisTemp.pathApp EQ '' THEN sv=DIALOG_MESSAGE('No path for results specified. Press OK to continue when current results (in clipboard) are pasted to a result file or ignored.', DIALOG_PARENT=evTop)
                    ENDIF

                    ;move files?
                    IF thisTemp.archive THEN BEGIN
                      archivePath=FILE_DIRNAME(structImgs.(0).filename)+'\Archive\'+datelist(q)+'\'
                      fi=FILE_INFO(archivePath)
                      IF fi.exists EQ 0 THEN FILE_MKDIR, archivePath
                      FOR i=0, N_ELEMENTS(tags)-1 DO BEGIN
                        fi=FILE_INFO(archivePath+FILE_BASENAME(structImgs.(i).filename))
                        IF fi.exists EQ 0 THEN file_move, structImgs.(i).filename, archivePath+FILE_BASENAME(structImgs.(i).filename)
                        structImgs.(i).filename=archivePath+FILE_BASENAME(structImgs.(i).filename)
                      ENDFOR
                      infoLogg=infoLogg+'Moved files for date '+structImgs.(0).acqDate+' to folder "Archive" in '+thisTemp.path+newline
                      fileList=getListOpenFiles(structImgs,0,marked, markedMulti)
                      WIDGET_CONTROL, listFiles, YSIZE=n_elements(fileList), SET_VALUE=fileList, SET_LIST_SELECT=0, SET_LIST_TOP=0
                      WIDGET_CONTROL, listFiles, SCR_YSIZE=170
                      WIDGET_CONTROL, lblLoadedN, SET_VALUE=STRING(n_elements(fileList), FORMAT='(i0)')+' )'
                    ENDIF;move files to 'Archive'

                  ENDIF; results GT 0
                ENDIF;images to work with
              ENDIF; QuickTemp selected
            ENDIF ELSE BEGIN; datelist(q) NE '', e.g. not aquired images like 'Patient Protocol' overview

              noAcqIds=WHERE(dates EQ '')
              FOR a=0, N_ELEMENTS(noAcqIds)-1 DO delAdr=[delAdr,structImgsAll.(a).filename]
            ENDELSE

          ENDFOR
          IF delAdr NE !Null THEN BEGIN
            IF thisTemp.deleteFiles THEN FILE_DELETE, delAdr, /QUIET;, /RECYCLE to recycle-bin?
          ENDIF
          structImgsAll=!Null
          copyHeader=oldCopyHeader
          transposeTable=oldTransposeTable
          redrawImg, 0,1
          updateInfo;calling updateTable
          updatePlot,1,1,0
          WIDGET_CONTROL, wtabResult, SET_TAB_CURRENT=0
          IF infoLogg NE '' THEN sv=DIALOG_MESSAGE(infoLogg, /INFORMATION, DIALOG_PARENT=evTop)
        ENDIF;dcm adr GT 0

      ENDIF ELSE BEGIN
        sv=DIALOG_MESSAGE('Found no valid DICOM files in selected folder.', DIALOG_PARENT=evTop)
        WIDGET_CONTROL, lblProgress, SET_VALUE=' '
      ENDELSE

    ENDIF ELSE sv=DIALOG_MESSAGE('Found no files in selected folder. (NB special characteres in file-path might not work well.)', DIALOG_PARENT=evTop);dirs
  ENDIF;path empty


end