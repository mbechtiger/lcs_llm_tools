* file : viewsJsonDescription.prc
* description : given model, create a full description of all view in JSON format
* created : marcel.bechtiger@domain-sa.ch - 20250303
* modified : 20250307

   if db='' or model='' 
       put/f fid=* 'Usage : @viewsJsonDescription.prc db=''X'',model=''Y'''
        return
   end_if

   set/pv db=$raise(db)
   set/pv model=$raise(model)
   set/pv view=$raise(view)

   set/pv dictFilename=db//'_'//model//'.json'
 
   put/f fid=* '*** viewsJsonDescription started ' $date ' - ' $time

   put/f fid=* 'Opening DICT file: ' dictFilename
   close/f fid=dict err=$continue
   delete/f '!dictFilename!'
   open/f '!dictFilename!' fid=dict intent=write recordlc=1000

   * open dictionary/DDB once
   discard/sets all err=$continue
   put/f fid=* 'Opening dictionary/DDB X' db '.USER'
   close/db X!db!.USER err=$continue
   open/db X!db!.USER intent=read wait=no err=ddbErr

   *************************************************************************
   ********** retrieve all views in model **********
   *************************************************************************

   * get view list for model
   find viewd where mvnm='!model!.'* order by mvnm end result=no
   acquire/pv members n1=viewNE
   if viewNE=0
      put/f fid=* 'No view for this model'
      jump prcEnd
   end_if

   * I=Integer, R=Real, D=Double, K=Cell, C=Character, E=Exact_binary,
   * P=Exact_decimal, A=Approximate, X=Complex, L=Logical, B=byte_string
   set/pv fieldDataTypeList_I='Integer'
   set/pv fieldDataTypeList_R='Real'
   set/pv fieldDataTypeList_D='Double'
   set/pv fieldDataTypeList_K='Cell'
   set/pv fieldDataTypeList_C='Character'
   set/pv fieldDataTypeList_E='Exact_binary'
   set/pv fieldDataTypeList_P='Exact_decimal'
   set/pv fieldDataTypeList_A='Approximate'
   set/pv fieldDataTypeList_X='Complex'
   set/pv fieldDataTypeList_L='Logical'
   set/pv fieldDataTypeList_B='Byte_string'

   * KS=System key, KD=Date key, DT=Date, NR=Number,
   * SI=Scientific, CH=Character, SH=Short text, TM=Time,
   * MY=Money, PN=Person name, TL=Title, UK=User key,
   * CK=Dupcheck key, TR=Translate, OT=Other, TS=Text stream,
   * SN=Section name, SL=Section level, SR=Section number,
   * ST=Section title, MI=Mimetype, TI=Timestamp,
   * SY=System
   set/pv fieldUsageList_KS='System key'
   set/pv fieldUsageList_KD='Date key'
   set/pv fieldUsageList_DT='Date'
   set/pv fieldUsageList_NR='Number'
   set/pv fieldUsageList_SI='Scientific'
   set/pv fieldUsageList_CH='Character'
   set/pv fieldUsageList_SH='Short text'
   set/pv fieldUsageList_TM='Time'
   set/pv fieldUsageList_MY='Money'
   set/pv fieldUsageList_PN='Person name'
   set/pv fieldUsageList_TL='Title'
   set/pv fieldUsageList_UK='User key'
   set/pv fieldUsageList_CK='Dupcheck key'
   set/pv fieldUsageList_TR='Translate'
   set/pv fieldUsageList_OT='Other'
   set/pv fieldUsageList_TS='Text stream'
   set/pv fieldUsageList_SN='Section name'
   set/pv fieldUsageList_SL='Section level'
   set/pv fieldUsageList_SR='Section number'
   set/pv fieldUsageList_ST='Section title'
   set/pv fieldUsageList_MI='Mimetype'
   set/pv fieldUsageList_TI='Timestamp'
   set/pv fieldUsageList_SY='System'
 
   * U=Unique, E=Exact, I=Inclusive, C=Catalog, 
   * X=Extended catalog 
   set/pv fieldIndexTypeList_U='Unique'
   set/pv fieldIndexTypeList_E='Exact'
   set/pv fieldIndexTypeList_I='Inclusive'
   set/pv fieldIndexTypeList_C='Catalog'
   set/pv fieldIndexTypeList_X='Extended catalog'

   *************************************************************************
   ********** DICT header **********
   *************************************************************************

   put/f fid=dict '{' 
   put/f fid=dict '  "database" : "' db '",'
   put/f fid=dict '  "model" : "' model '",'
   put/f fid=dict '  "created" : "' $date ' - ' $time '",'
   put/f fid=dict '  "views_ne" : ' viewNE ','
   put/f fid=dict '  "views" :'
   put/f fid=dict '  {'

   * build view list as getViewFieldsInfo discards all previous sets
   for ii=1,viewNE
      get/v [0,ii]viewd intent=read
      assign/pv mvnm=mvnm
      set/pv view!ii!=$item(2,'.',mvnm)
   end_for

   * call getViewFieldsInfo with TRACE=NO OPENCLOSEDDB=NO
   * it sets /gv variables with view/fields characteristics
   for ii=1,viewNE
      set/pv view=view!ii!
      put/f fid=* view

      @getViewFieldsInfo, '!db!', '!model!', '!view!', 'NO', 'NO'
      if getViewFieldsInfoRC<>0
         jump prcEnd
      end_if

      put/f fid=dict '    "' view '" :'
      put/f fid=dict '    {'
      put/f fid=dict '      "entry" : ' ii ','
      put/f fid=dict '      "name" : "' view '",'
      put/f fid=dict '      "source" : "' viewSource '",'
      put/f fid=dict '      "style" : "' viewStyle '",'
      put/f fid=dict '      "uniqueField" : "' viewUniqueField '",'
      put/f fid=dict '      "streamField" : "' viewStreamField '",'
      put/f fid=dict '      "fields_ne" : ' fieldNE ','
      put/f fid=dict '      "fields" :'
      put/f fid=dict '      {'

      for jj=1,fieldNE

         * replace code by label
         set/pv s=fieldDataType!jj!
         set/pv fieldDataType=fieldDataTypeList_!s!

         * replace code by label
         set/pv s=fieldUsage!jj!
         set/pv fieldUsage=fieldUsageList_!s!

         * replace code by label
         set/pv s=fieldIndexType!jj!
         if s='-'
            set/pv fieldIndexType='None'
         else
           set/pv fieldIndexType=fieldIndexTypeList_!s!
         end_if

         put/f fid=* '   ' fieldName!jj!
         put/f fid=dict '        "' fieldName!jj! '" :'
         put/f fid=dict '        {'
         put/f fid=dict '          "entry" : ' jj ','
         put/f fid=dict '          "name" : "' fieldName!jj! '",'
         put/f fid=dict '          "source" : "' fieldSource!jj! '",'
         put/f fid=dict '          "type" : "' fieldDataType '",'
         put/f fid=dict '          "usage" : "' fieldUsage '",'
         put/f fid=dict '          "len" : "' fieldLength!jj! '",'
         put/f fid=dict '          "occMin" : ' fieldMinOcc!jj! ','
         put/f fid=dict '          "occMax" : ' fieldMaxOcc!jj! ','
         put/f fid=dict '          "virtual" : "' when!jj! '",'
         put/f fid=dict '          "isDate" : "' fieldIsDate!jj! '",'
         put/f fid=dict '          "idxType" : "' fieldIndexType '"'
         if jj=fieldNE
            put/f fid=dict '        }'
         else
            put/f fid=dict '        },'
         end_if
      end_for
      put/f fid=dict '      }'

      if ii=viewNE
         put/f fid=dict '    }'
      else
         put/f fid=dict '    },'
      end_if
   end_for

   *************************************************************************
   ********** DICT footer **********
   *************************************************************************

   put/f fid=dict '  }'
   put/f fid=dict '}'
   close/f fid=dict
  
   jump prcEnd

   *************************************************************************
   ********** errors and termination **********
   *************************************************************************

dbErr:
   put/f fid=* 'Cannot open database, check if it is defined and available and if you are authorized'
   jump prcEnd

prcEnd:
   close/db X!db!.USER err=$continue
   close/f fid=dict err=$continue
   put/f fid=* '*** viewsJsonDescription terminated ' $date ' - ' $time
   return
   *exit
*
