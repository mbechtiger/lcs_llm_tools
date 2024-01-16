* file : getInfo.prc
* description :
*    1) list virtual fields (on_add, on_put, on_get) in all views of the database model
*    2) list non-empty conventional/continuous tables in database
*    given a database model that contains all records/view
*    the model may be created with :
*    dmsa uid=sauid upw=saupw
*       disc k=1 uid=*
*       wait 5
*       show/si k=1
*       exit
*    dmdba uid=sauid upw=saupw db=tout mode=statement action=update get=m.ddl apply_if_ok=yes input=z.inp
*    where m.ddl contains
*       user_data_model;
*       generate_udm XYZ_DUMP, type=fqm, form=no;
*    and z.inp contains
*       z
* usage : @getInfo db='bold' model='all'
* created :  marcel.bechtiger@domain-sa.ch - 20231220
* modified :

   * try to use environment variables
   assign/host/pv hostDb=DB
   if hostDb<>''
      set/pv db=hostDb
   else
      if db=''
         inquire/pv db,'Enter database name>'
      end_if
   end_if
   set/pv db=$raise(db)

   assign/host/pv hostModel=MODEL
   if hostModel<>''
      set/pv model=hostModel
   else
      if model=''
         inquire/pv model,'Enter model name>'
      end_if
   end_if
   set/pv model=$raise(model)

   * open logfile
   set/pv logFile=db//'_getDbInfo.log'
   put/f fid=* 'logfile is ' logFile
   close/f fid=l err=$continue
   delete/f '!logFile!'
   open/f '!logFile!' fid=l intent=write
   put/f fid=l '*** started ' $date ' - ' $time

   * open DB
   put/f fid=* 'Opening database'
   put/f fid=l 'Opening database ' db '.' model
   close/db !db!.!model! err=$continue
   open/db !db!.!model! intent=read wait=no err=dbErr

   * open dictionary/DDB
   put/f fid=* 'Opening dictionary'
   put/f fid=l 'Opening dictionary X' db '.USER'
   close/db X!db!.USER err=$continue
   open/db X!db!.USER intent=read wait=no err=ddbErr

   * get virtual fields list, where WHEN is not null or the referenced
   * optional PARAMETER_SET WHEN is not null
   * WHEN can be A(dd), G(et), P(ut)
   find red where when<>null order by renms(1) end result=no
   acquire/pv members n1=virtualFieldsNE
   if virtualFieldsNE<>0
      put/f fid=* '--- ' virtualFieldsNE ' RECORD virtual fields with SET_WHEN'
      put/f fid=l '--- ' virtualFieldsNE ' RECORD virtual fields with SET_WHEN'
      for i=1,virtualFieldsNE
         get/v [0,i]red
         assign/pv renms=renms(1)
         assign/pv when=when
         if when='A'
            set/pv whenS='Add'
         else_if when='G'
            set/pv whenS='Get'
         else_if when='P'
            set/pv whenS='Put'
         end_if
         put/f fid=* renms ' : ' whenS
         put/f fid=l renms ' : ' whenS
      end_for
   end_if
   discard/set 0

   find red,epsd where red.epsnm:=epsd.name and epsd.when<>null order by renms(1) end result=no
   acquire/pv members n1=virtualParameterSetNE
   if virtualParameterSetNE<>0
      put/f fid=* '--- ' virtualParameterSetNE ' RECORD virtual fields with SET_WHEN in PARAMETER_SET '
      put/f fid=l '--- ' virtualParameterSetNE ' RECORD virtual fields with SET_WHEN in PARAMETER_SET '
      for i=1,virtualParameterSetNE
         get/v [0,i]red
         assign/pv renms=renms(1)
         get/v [0,i]epsd
         assign/pv when=when
         if when='A'
            set/pv whenS='Add'
         else_if when='G'
            set/pv whenS='Get'
         else_if when='P'
            set/pv whenS='Put'
         end_if
         put/f fid=* renms ' : ' whenS
         put/f fid=l renms ' : ' whenS
      end_for
   end_if
   discard/set 0

   * get list of views for given model
   find viewd where mvnm='!model!.'* order by mvnm end result=no
   acquire/pv members n1=dictionaryViewsNE
   acquire/pv lastset n1=viewdSetNB
   put/f fid=* '--- ' dictionaryViewsNE ' views defined in model ' db '.' model ' will be checked for content'
   put/f fid=l '--- ' dictionaryViewsNE ' views defined in model ' db '.' model ' will be checked for content'
   for i=1,dictionaryViewsNE
      get/v [viewdSetNB,i]viewd
      assign/pv mvnm=mvnm
      set/pv viewName!i!=$item(2,'.',mvnm)

      assign/pv source=source
      find recd where recnm='!source!' end result=no
      get/v [0,1]recd
      assign/pv style=style
      * C=Conventional,D=Continuous document,S=Sectioned document
      set/pv recordStyle!i!=style
      if style='C'
         put/f fid=* viewName!i! ' : Conventional'
         put/f fid=l viewName!i! ' : Conventional'
      else_if style='D'
         put/f fid=* viewName!i! ' : Continous'
         put/f fid=l viewName!i! ' : Continous'
      else_if style='S'
         put/f fid=* viewName!i! ' : Sectioned'
         put/f fid=l viewName!i! ' : Sectioned'
      end_if
      discard/set 0
   end_for

   * done with DDB !
   close/db X!db!.USER err=$continue
   set/default db=!db!
   set/default model=!model!

   set/pv totalOccurencesNB=0
   put/f fid=* '--- counting occurences'
   put/f fid=l '--- counting occurences'
   * for each view defined in the given model, see if there are occurences
   for i=1,dictionaryViewsNE
      set/pv viewName=viewName!i!
      set/pv recordStyle=recordStyle!i!
      find !viewName! end result=no
      acquire/pv members n1=mem
      if mem > 0
         set/pv totalOccurencesNB=totalOccurencesNB+mem
         put/f fid=* i ') ' mem ' ' viewName ' occurences'
         put/f fid=l i ') ' mem ' ' viewName ' occurences'
      else
         put/f fid=* i ') No ' viewName ' occurence'
         put/f fid=l i ') No ' viewName ' occurence'
      end_if
   end_for

   put/f fid=* 'Total of ' totalOccurencesNB ' occurences in database/model'
   put/f fid=l 'Total of ' totalOccurencesNB ' occurences in database/model'

   jump prcEnd

dbErr:
   put/f fid=* 'Cannot open database, check if it is defined and available and if you are authorized'
   put/f fid=l 'Cannot open database, check if it is defined and available and if you are authorized'
   jump prcEnd

ddbErr:
   put/f fid=* 'Cannot open database dictionary, check if you are authorized'
   put/f fid=l 'Cannot open database dictionary, check if you are authorized'
   jump prcEnd

prcEnd:
   *put/f fid=* 'Closing logfile: ' logFile
   put/f fid=l '*** terminated ' $date ' - ' $time
   * logfile
   close/f fid=l
   return
   *exit
*
