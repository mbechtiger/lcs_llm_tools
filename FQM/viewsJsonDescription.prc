* file : viewsJsonDescription.prc
* description : given model, create a full description of all view in JSON format
* created : marcel.bechtiger@domain-sa.ch - 20250303
* modified : 

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
         put/f fid=* '   ' fieldName!jj!
         put/f fid=dict '        "' fieldName!jj! '" :'
         put/f fid=dict '        {'
         put/f fid=dict '          "entry" : ' jj ','
         put/f fid=dict '          "name" : "' fieldName!jj! '",'
         put/f fid=dict '          "source" : "' fieldSource!jj! '",'
         put/f fid=dict '          "type" : "' fieldDataType!jj! '",'
         put/f fid=dict '          "len" : "' fieldLength!jj! '",'
         put/f fid=dict '          "occMin" : ' fieldMinOcc!jj! ','
         put/f fid=dict '          "occMax" : ' fieldMaxOcc!jj! ','
         put/f fid=dict '          "virtual" : "' when!jj! '",'
         put/f fid=dict '          "isDate" : "' fieldIsDate!jj! '",'
         put/f fid=dict '          "idxType" : "' fieldIndexType!jj! '"'
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
