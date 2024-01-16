* file : getViewFieldsInfo.prc
* description : given database/model/view, retrieve fields characteristics
* usage : @getViewFieldsInfo, '!databaseName!', '!modelName!', '!viewName!'
* created : marcel.bechtiger@domain-sa.ch - 20231223
* modified :

   set/pv databaseName=p1
   set/pv modelName=p2
   set/pv viewName=p3

   *************************************************************************
   ********** get view fields from database structure information
   *************************************************************************

   * note: there can be several unique fields defined in a record
   * if none or several exit, use an incremental value for the eventual
   * continuous exported document file
   set/gv viewUniqueField=''
   set/gv virtualFieldsList=''

   * open dictionary/DDB
   discard/sets all err=$continue
   put/f fid=* 'Opening dictionary/DDB X' databaseName '.USER'
   close/db X!databaseName!.USER err=$continue
   open/db X!databaseName!.USER intent=read wait=no err=ddbErr

   * get view characteristics
   find viewd where mvnm='!modelName!.!viewName!' end result=no
   acquire/pv members n1=memberCount
   if memberCount=0
      put/f fid=* 'No such view'
      jump prcEnd
   end_if
   get/v [0,1]viewd intent=read
   assign/pv source=source
   find recd where recnm='!source!' end result=no
   get/v [0,1]recd intent=read
   assign/pv style=style
   * C=Conventional,D=Continuous document,S=Sectioned document
   set/gv viewIsConventional='N'
   set/gv viewIsContinuous='N'
   set/gv viewIsSectioned='N'
   if style='C'
      set/gv viewIsConventional='Y'
   else_if style='D'
      set/gv viewIsContinuous='Y'
   else_if style='S'
      set/gv viewIsSectioned='Y'
   end_if

   * get fields characteristics
   find ved where mvenm='!modelName!.!viewName!.'* and kind='EI' +
       order by mvenm end result=no
   acquire/pv members n1=fieldNE
   set/gv fieldNE=fieldNE
   set/gv viewUniqueField=''
   set/gv viewStreamField=''

   for i=1,fieldNE
      get/v [0,i]ved intent=read
      assign/pv mvenm=mvenm
      assign/pv source=source
      set/gv fieldName!i!=$item(3,'.',mvenm)
      get/v [renms='!source!']red
      assign/pv dt=dt
      * I=Integer, R=Real, D=Double, K=Cell, C=Character, E=exact_binary,
      * P=exact_decimal, A=approximate, X=complex, L=logical, B=byte_string
      *put/f fid=* fieldName!i! ' dt: ' dt
      set/gv fieldIsChar!i!='N'
      set/gv fieldIsLogical!i!='N'
      if dt='C'
         set/gv fieldIsChar!i!='Y'
      end_if
      if dt='L'
         set/gv fieldIsLogical!i!='Y'
      end_if
      assign/pv uniq=uniq
      * Y=Yes, N=No
      *put/f fid=* fieldName!i! ' uniq: ' uniq
      if uniq='Y'
         if viewUniqueField=''
            set/gv viewUniqueField=fieldName!i!
         else
            set/gv viewUniqueField='multipleUniqueFieldsDefined'
         end_if
      end_if
      * cannot use pv named 'usage'
      assign/pv myUsage=usage
      *put/f fid=* fieldName!i! ' usage: ' myUsage
      * KS=System key, KD=Date key, DT=Date, NR=Number,
      * SI=Scientific, CH=Character, SH=Short text, TM=Time,
      * MY=Money, PN=Person name, TL=Title, UK=User key,
      * CK=Dupcheck key, TR=Translate, OT=Other, TS=Text stream,
      * SN=Section name, SL=Section level, SR=Section number,
      * ST=Section title, MI=Mimetype, TI=Timestamp,
      * SY=System
      set/gv fieldIsDate!i!='N'
      set/gv fieldHasSubfields!i!='N'
      if $match(myUsage,'KD.DT')<>0
         set/gv fieldIsDate!i!='Y'
      else_if myUsage='TS'
         set/gv viewStreamField=fieldName!i!
      end_if
      * use output format to check for date : <??/DATE??<
      assign/pv out=out
      if $match('/DATE',$raise(out))<>0
         set/gv fieldIsDate!i!='Y'
      end_if
      assign/pv minocc=minocc
      assign/pv maxocc=maxocc
      if maxocc^=1
         set/gv fieldHasSubfields!i!='Y'
      end_if
      assign/pv prec=prec
      if prec^=0
         assign/pv scale=scale
         if scale^=0
            set/pv i4=prec//'.'//scale
         else
            set/pv i4=prec
         end_if
      else
         assign/pv minlc=minlc
         assign/pv maxlc=maxlc
         set/pv i4=minlc//':'//maxlc
      end_if
      set/gv fieldLength!i!=i4
      * is virtual (these may be ignore from export) ? cannot use pv named 'when'
      assign/gv myWhen=when
      set/pv whenS=''
      if myWhen='A'
         set/pv whenS='Add'
      else_if myWhen='G'
         set/pv whenS='Get'
      else_if myWhen='P'
         set/pv whenS='Put'
      else
         set/pv whenS='N'
      end_if
      set/gv when!i!=whenS
      if myWhen<>''
         set/gv virtualFieldsList=virtualFieldsList//fieldName!i!//':'//when!i!//' '
      end_if
      put/f fid=* '>>>>> FIELD ' fieldName!i! ' isChar:' fieldIsChar!i! ' length:' fieldLength!i! +
         ' hasSubfields:' fieldHasSubfields!i! ' isDate:' fieldIsDate!i! +
         ' isLogical:' fieldIsLogical!i! ' isVirtual:' when!i!
   end_for

   close/db X!databaseName!.USER err=$continue

   put/f fid=* '>>>>> VIEW ' viewName ' isConventional:' viewIsConventional +
      ' isContinuous:' viewIsContinuous ' isSectioned:' viewIsSectioned +
      ' uniqueField:' viewUniqueField ' streamField:' viewStreamField

   if viewIsContinuous='Y'
      put/f fid=* 'Note that dumping CONTinous view is not fully supported'
   else_if viewIsSectioned='Y'
      put/f fid=* 'Note that dumping SECTioned view is not supported'
   end_if

   if virtualFieldsList<>''
      put/f fid=* '>>>>> Virtual fields: ' virtualFieldsList
   end_if

   set/gv getViewFieldsInfoRC=0
   return

   *************************************************************************
   ********** errors and termination **********
   *************************************************************************

ddbErr:
   put/f fid=* 'Cannot open database dictionary, check if you are authorized'
   set/gv getViewFieldsInfoRC=-1
   return

prcErr:
   close/db !databaseName!.!modelName! err=$continue
   put/f fid=* 'Error in getViewFieldsInfo, abort'
   set/gv getViewFieldsInfoRC=-2
   return
