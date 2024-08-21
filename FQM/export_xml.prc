* file : export_xml.prc
* description : given view, export all fields to structured XML,
*            warn if CONTinous/SECTioned view
* created : marcel.bechtiger@domain-sa.ch - 20231223
* modified : 

   if databaseName='' or modelName='' or viewName=''
       put/f fid=* 'Usage : @export_xml.prc databaseName=''X'',modelName=''Y'',viewName=''Z''{,findCommand=''FQM find command''}{,ignoreFields=''field1,field2,   ''}'
       put/f fid=* '- findCommand must be without view/where in the form ''eno>0 order by eno'''
       put/f fid=* '- if findCommand is void, all records are extracted'
       put/f fid=* '- if ignoreFields list is provided, those fields listed will be ignored from export'
       put/f fid=* '- the TEXT_STREAM field is currently ignored in CONTinous views'
       put/f fid=* 'Example : @export_xml databasename=''tour'' modelname=''all'' viewname=''employee'' ignorefields=''itin,notes'''
       return
   end_if

   set/pv databaseName=$raise(databaseName)
   set/pv modelName=$raise(modelName)
   set/pv viewName=$raise(viewName)
   set/pv ignoreFields=$raise(ignoreFields)

   if ignoreFields<>''
      put/f fid=* 'The following fields will be ignored from the export : ' ignoreFields
   end_if

   set/pv xmlFilename=viewName//'.xml'
   set/pv quote='"'
   set/pv escapedSingleQuote='\'''

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
   ********** open XML file
   *************************************************************************

   put/f fid=* 'Opening XML file: ' xmlFilename
   close/f fid=xml err=$continue
   delete/f '!xmlFilename!'
   open/f '!xmlFilename!' fid=xml intent=write recordlc=16000

   put/f fid=xml '<?xml version="1.0" encoding="UTF-8"?>'
   put/f fid=xml '<' viewName 'S>'

   *************************************************************************
   ********** build
   **********
   ********** special case ARRAY : x,y,z --> ['x','y','z']
   ********** special case DATE : 20230901 --> '2023-09-01'
   ********** special case DATE ARRAY : 20230901,20230902 --> ARRAY ['2023-09-01','2023-09-02']
   ********** special case escape quote ' --> \'
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

   put/f fid=xml '  <COUNT>' recordNE '</COUNT>'

   for recordNb=1, recordNE
      get/v [0,recordNb]!viewName! intent=read

      put/f fid=xml '  <' viewName '>'

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
            set/pv allSubfieldsBuff=''

            * loop through subfields
            assign/occ/pv occ=!fieldName!
            for subfieldNb=1,occ
               assign/pv subfieldBuff=!fieldName!(!subfieldNb!)
               *put/f fid=* '>>>>>' fieldName(!subfieldNb!) ':' subfieldBuff

               if subfieldBuff<>''
                  if fieldIsChar!fieldNb!='Y'
                     * if any, escape single quote
                     set/pv p=$match(singleQuote,subfieldBuff)
                     if p>0
                        set/pv subfieldBuff=subfieldBuff[1:p-1]//escapedSingleQuote//subfieldBuff[p+1:$lc(subfieldBuff)]
                        set/pv p=$match(fieldDelimiter,subfieldBuff)
                        while p>0
                           set/pv subfieldBuff=subfieldBuff[1:p-1]//escapedSingleQuote//subfieldBuff[p+1:$lc(subfieldBuff)]
                           set/pv p=$match(fieldDelimiter,subfieldBuff)
                        end_while
                     end_if
                     set/pv subfieldBuff=quote//subfieldBuff//quote
                  else_if fieldIsDate!fieldNb!='Y'
                     set/pv subfieldBuff=quote//subfieldBuff[1:4]//'-'//subfieldBuff[5:6]//'-'//subfieldBuff[7:8]//quote
                  else_if fieldIsLogical!fieldNb!='Y'
                     if subfieldBuff=1
                        set/pv subfieldBuff='true'
                     else_if subfieldBuff=0
                        set/pv subfieldBuff='false'
                     else
                        set/pv subfieldBuff='NULL'
                     end_if
                  end_if

                  if allSubfieldsBuff<>''
                     set/pv allSubfieldsBuff=allSubfieldsBuff//','
                  end_if
                  set/pv allSubfieldsBuff=allSubfieldsBuff//subfieldBuff
               end_if
            end_for

            * append allSubfields to field buffer
            * decide how to handle empty fields - NULL, '', don't output
            if allSubfieldsBuff<>''
               if fieldHasSubfields!fieldNb!='Y'
                  set/pv allSubfieldsBuff='['//allSubfieldsBuff//']'
               end_if
               set/pv fieldBuff=fieldBuff//allSubfieldsBuff
               put/f fid=xml '   <' fieldName '>' fieldBuff '</' fieldName '>'
            else
               *set/pv fieldBuff='NULL'
               set/pv fieldBuff=''
               put/f fid=xml '   <' fieldName '>' fieldBuff '</' fieldName '>'
            end_if

         end_if
      end_for

      *************************************************************************
      ********** optionally, export blob
      *************************************************************************

      if viewIsContinuous='Y'
         * implement text_stream export as needed
      end_if

      put/f fid=xml '  </' viewName '>'

   end_for

   put/f fid=xml '</' viewName 'S>'

   jump prcEnd

   *************************************************************************
   ********** errors and termination **********
   *************************************************************************

dbErr:
   put/f fid=* 'Cannot open database, check if it is defined and available and if you are authorized'
   jump prcEnd

ddbErr:
   put/f fid=* 'Cannot open database dictionary, check if you are authorized'
   jump prcEnd

findCommandErr:
   inquire/pv findCommand,'complete with proper FQM syntax (optional order by) : FIND !viewName! WHERE   '
   jump execFindCommand

prcEnd:
   close/db X!databaseName!.USER err=$continue
   close/db !databaseName!.!modelName! err=$continue
   close/f fid=xml err=$continue
   put/f fid=* '*** hvu_dump_script log terminated ' $date ' - ' $time
   return
   *exit
*
