* file : export_csv.prc
* description : given view, export all fields to CSV,
*            warn if CONTinous/SECTioned view
* created : marcel.bechtiger@domain-sa.ch - 20231223
* modified : 

   if databaseName='' or modelName='' or viewName=''
       put/f fid=* 'Usage : @export_csv.prc databaseName=''X'',modelName=''Y'',viewName=''Z''{,findCommand=''FQM find command''}{,ignoreFields=''field1,field2,...''}'
       put/f fid=* '- findCommand must be without view/where in the form ''eno>0 order by eno'''
       put/f fid=* '- if findCommand is void, all records are extracted'
       put/f fid=* '- if ignoreFields list is provided, those fields listed will be ignored from export'
       put/f fid=* '- the TEXT_STREAM field is currently ignored in CONTinous views'
       put/f fid=* 'Example : @export_csv databasename=''tour'' modelname=''all'' viewname=''employee'' ignorefields=''itin,notes'''
       return
   end_if

   set/pv databaseName=$raise(databaseName)
   set/pv modelName=$raise(modelName)
   set/pv viewName=$raise(viewName)
   set/pv ignoreFields=$raise(ignoreFields)

   if ignoreFields<>''
      put/f fid=* 'The following fields will be ignored from the export : ' ignoreFields
   end_if

   set/pv fieldDelimiter='#'
   set/pv subfieldDelimiter=';'
   set/pv bracketChar='@'
   set/pv csvFilename=viewName//'.csv'

   put/f fid=* '*** hvu_dump_script log started ' $date ' - ' $time

   * uses /gv variables to load fields characteristics
   @getViewFieldsInfo, '!databaseName!', '!modelName!', '!viewName!'
   if getViewFieldsInfoRC<>0
      jump prcEnd
   end_if

   if viewIsSectioned='Y'
      jump prcEnd
   end_if

   * open DB
   put/f fid=* 'Opening database ' databaseName '.' modelName
   close/db !databaseName!.!modelName! err=$continue
   open/db !databaseName!.!modelName! intent=read wait=no err=dbErr

   *************************************************************************
   ********** build and write field names to CSV file header
   *************************************************************************

   put/f fid=* 'Opening CSV file: ' csvFilename
   close/f fid=csv err=$continue
   delete/f '!csvFilename!'
   open/f '!csvFilename!' fid=csv intent=write recordlc=16000
   set/pv line=''

   for i=1,fieldNE
       * append field, except if text_stream
       set/pv fieldName=fieldName!i!
       set/pv fieldName='!fieldName!'
       if fieldName^=viewStreamField and $match(fieldName,ignoreFields)=0
          if i>1
              set/pv line=line//fieldDelimiter
          end_if
          set/pv line=line//fieldName
       end_if
   end_for

   put/f fid=csv line

   *************************************************************************
   ********** extract database data in csv format
   *************************************************************************

   * execute provided find command; if invalid, try again
   * the view name is hard coded here to avoid discrepencies with the previous dictionary requests
   on/syntax findCommandErr
   on/exception findCommandErr
execFindCommand:
   if findCommand<>''
      find !viewName! where !findCommand! end result=no
   else
      find !viewName! end result=no
   end_if
   on/syntax
   on/exception
   acquire/pv members n1=recordNE
   put/f fid=* recordNE ' ' viewName ' record(s) to export'

   for recordNb=1, recordNE
       get/v [0,recordNb]!viewName! intent=read

       * preferred way to get system_key
       set/pv systemKey=$primary_key($lastset,recordNb)
       if systemKey^=''
          set/pv viewUniqueValue=systemKey
       end_if

       * build csv data line
       set/pv line=''

       * loop through fields
       for fieldNb=1,fieldNE
          set/pv fieldBuff=''
          set/pv fieldName=fieldName!fieldNb!
          set/pv fieldName='!fieldName!'

          *put/f fid=* '>>>>>' fieldName ' in list ? ' $match(fieldName,ignoreFields)

          * append field, except if text_stream which is a special case treated below
          * and check if field name appears in ignored fields list
          if fieldName^=viewStreamField and $match(fieldName,ignoreFields)=0
              assign/pv value=!fieldName!
              set/pv value=$squeeze(value)
              if fieldName=viewUniqueField and viewUniqueValue=''
                 set/pv viewUniqueValue=value
              end_if
              *put/f fid=* '>>>>' viewUniqueField ',' viewUniqueValue ',' systemKey

              * loop through subfields
              assign/occ/pv occ=!fieldName!
              for subfieldNb=1,occ
                 assign/pv subfieldBuff=!fieldName!(!subfieldNb!)
                 *put/f fid=* '>>>>>' fieldName(!subfieldNb!) ':' subfieldBuff

                 * make sure the CSV delimiter doesn't exist in the subfield data
                 set/pv p=$match(fieldDelimiter,subfieldBuff)
                 if p>0
                     set/pv subfieldBuff=subfieldBuff[1:p-1]//bracketChar//subfieldBuff[p+1:$lc(subfieldBuff)]
                     set/pv p=$match(fieldDelimiter,subfieldBuff)
                     while p>0
                        set/pv subfieldBuff=subfieldBuff[1:p-1]//bracketChar//subfieldBuff[p+1:$lc(subfieldBuff)]
                        set/pv p=$match(fieldDelimiter,subfieldBuff)
                     end_while
                 end_if

                 * append to field buffer
                 if subfieldBuff<>''
                     if fieldBuff<>''
                        set/pv fieldBuff=fieldBuff//subfieldDelimiter
                     end_if
                     set/pv fieldBuff=fieldBuff//subfieldBuff
                 end_if
              end_for

              if fieldNb>1
                 set/pv line=line//fieldDelimiter
              end_if
              set/pv line=line//fieldBuff
          end_if
       end_for

       *************************************************************************
       ********** optionally export blob to file
       *************************************************************************

       if viewIsContinuous='Y'
          * implement text_stream export as needed
       end_if

       *put/f fid=* '>>>>>line is ' $lc(line) ' long'
       put/f fid=csv line
   end_for

   jump prcEnd

   *************************************************************************
   ********** errors and termination **********
   *************************************************************************

dbErr:
   put/f fid=* 'Cannot open database, check if it is defined and available and if you are authorized'
   jump prcEnd

findCommandErr:
   inquire/pv findCommand,'complete with proper FQM syntax (optional order by) : FIND !viewName! WHERE...'
   jump execFindCommand

prcEnd:
   close/db X!databaseName!.USER err=$continue
   close/db !databaseName!.!modelName! err=$continue
   close/f fid=csv err=$continue
   put/f fid=* '*** hvu_dump_script log terminated ' $date ' - ' $time
   return
   *exit
*
