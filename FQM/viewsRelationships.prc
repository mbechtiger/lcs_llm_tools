* file : viewRelationships.prc
* description : given model, create "graphviz" DOT representing relationships between views
* created : marcel.bechtiger@domain-sa.ch - 20250214
* modified : 

   if db='' or model='' 
       put/f fid=* 'Usage : @viewRelationships.prc db=''X'',model=''Y'''
        return
   end_if

   set/pv db=$raise(db)
   set/pv model=$raise(model)
   set/pv view=$raise(view)

   set/pv dotFilename=db//'_'//model//'.dot'
 
   put/f fid=* '*** viewRelationships started ' $date ' - ' $time

   put/f fid=* 'Opening DOT file: ' dotFilename
   close/f fid=dot err=$continue
   delete/f '!dotFilename!'
   open/f '!dotFilename!' fid=dot intent=write recordlc=1000

   * open dictionary/DDB once
   discard/sets all err=$continue
   put/f fid=* 'Opening dictionary/DDB X' db '.USER'
   close/db X!db!.USER err=$continue
   open/db X!db!.USER intent=read wait=no err=ddbErr

   *************************************************************************
   ********** DOT header **********
   *************************************************************************

   put/f fid=dot '##graphviz representation of all views in the database model ' db '.' model
   put/f fid=dot '##Command to get the layout: "dot -Gsize=10,15 -Tpdf thisfile > thisfile.pdf"'
   put/f fid=dot ''
   put/f fid=dot 'digraph UML_Class_diagram {'
   put/f fid=dot '  graph ['
   put/f fid=dot '    label="Database relationships' db '.' model '"'
   put/f fid=dot '    labelloc="t"'
   put/f fid=dot '    fontname="Helvetica,Arial,sans-serif"'
   put/f fid=dot '  ]'
   put/f fid=dot '  node ['
   put/f fid=dot '    fontname="Helvetica,Arial,sans-serif"'
   put/f fid=dot '    shape=record'
   put/f fid=dot '    style=filled'
   put/f fid=dot '    fillcolor=gray95'
   put/f fid=dot '  ]'

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

   * build view list as getViewFieldsInfo discards all previous sets
   for ii=1,viewNE
      get/v [0,ii]viewd intent=read
      assign/pv mvnm=mvnm
      set/pv view!ii!=$item(2,'.',mvnm)
   end_for

   * call getViewFieldsInfo with TRACE=NO OPENCLOSEDDB=NO
   * it sets /gv variables with fields characteristics
   for ii=1,viewNE
      set/pv view=view!ii!
      put/f fid=* view

      @getViewFieldsInfo, '!db!', '!model!', '!view!', 'NO', 'NO'
      if getViewFieldsInfoRC<>0
         jump prcEnd
      end_if

      * use viewSource as port for assert links below
      put/f fid=dot ''
      put/f fid=dot '"' viewSource '" ['
      put/f fid=dot '  shape=plain'
      put/f fid=dot '  label=<<table border="0" cellborder="1" cellspacing="0" cellpadding="4">'
      put/f fid=dot '      <tr><td align="left"><b>' view '</b> Style=' viewStyle ', Src=' viewSource ',</td></tr>'
      put/f fid=dot '      <tr><td>'
      put/f fid=dot '         <table border="0" cellborder="0" cellspacing="0" >'

      * use fieldSource as port for assert links below
      for jj=1,fieldNE
         *put/f fid=* '   ' fieldName!jj!
         put/f fid=dot '           <tr><td align="left" port="' fieldSource!jj! '">' fieldName!jj! +
            '</td><td align="left">Src=' fieldSource!jj! +
            ', Type=' fieldDataType!jj! ', Len=' fieldLength!jj! ', Occ=' fieldMinOcc!jj! ':' fieldMaxOcc!jj! +
            ', Virtual=' when!jj! ', Date=' fieldIsDate!jj! ', Idx=' fieldIndexType!jj! +
            '</td></tr>'
      end_for

      put/f fid=dot '         </table>'
      put/f fid=dot '      </td></tr>'
      put/f fid=dot '      <tr><td align="left">VirtualFields=' virtualFieldsList '</td></tr>'
      put/f fid=dot '   </table>>'
      put/f fid=dot ']'
      put/f fid=dot ''
   end_for

   *************************************************************************
   ********** draw relationships using inter-record asserts, if any **********
   *************************************************************************
   put/f fid=dot '[dir=back arrowtail=empty style=""]'

   find asrtd where kind='R' order by recnm(2) end result=no
   acquire/pv members n1=asrtdNE
   for ii=1,asrtdNE
      get/v [0,ii]asrtd
      assign/pv elemnm1=elemnm(1)
      set/pv elemnm1_1=$item(1,'.',elemnm1)
      set/pv elemnm1_2=$item(2,'.',elemnm1)
      assign/pv elemnm2=elemnm(2)
      set/pv elemnm2_1=$item(1,'.',elemnm2)
      set/pv elemnm2_2=$item(2,'.',elemnm2)
      put/f fid=dot elemnm2_1 ':' elemnm2_2 ' -> ' elemnm1_1 ':' elemnm1_2 ';'
      *put/f fid=dot elemnm2_1 ':' elemnm2_2 ' -> ' elemnm1_1 ':' elemnm1_2 ' [xlabel="' elemnm2 '->' elemnm1 '"];'
   end_for

   *************************************************************************
   ********** DOT footer **********
   *************************************************************************

   put/f fid=dot '}'
   close/f fid=dot
  
   jump prcEnd

   *************************************************************************
   ********** errors and termination **********
   *************************************************************************

dbErr:
   put/f fid=* 'Cannot open database, check if it is defined and available and if you are authorized'
   jump prcEnd

prcEnd:
   close/db X!db!.USER err=$continue
   close/f fid=dot err=$continue
   put/f fid=* '*** viewRelationships terminated ' $date ' - ' $time
   return
   *exit
*
