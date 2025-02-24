* file : getViewFieldsInfo.prc
* description : given database/model/view, retrieve fields characteristics
* usage : @getViewFieldsInfo, '!databaseName!', '!modelName!', '!viewName!', '!trace:Yes|No!', '!openCloseDDB:Yes|No!'
* created : marcel.bechtiger@domain-sa.ch - 20231223
* modified : 20240821, 20250130, 20250214

   set/pv databaseName=p1
   set/pv modelName=p2
   set/pv viewName=$raise(p3)
   set/pv trace=$raise(p4)
   if $substr(trace,1,1) = 'Y'
      set/pv trace='YES'
   else
      set/pv trace='NO'
   end_if
   set/pv openCloseDdb=$raise(p5)
   if $substr(openCloseDdb,1,1) = 'N'
      set/pv openCloseDdb='NO'
   else
      set/pv openCloseDdb='YES'
   end_if

   *************************************************************************
   ********** get view fields from database structure information
   *************************************************************************

   * note: there can be several unique fields defined in a record
   * if none exists or several exist, use an incremental value for the eventual
   * continuous exported document file
   set/gv viewUniqueField=''
   set/gv virtualFieldsList=''

   * open dictionary/DDB
   discard/sets all err=$continue
   if openCloseDdb='YES'
      put/f fid=* 'Opening dictionary/DDB X' databaseName '.USER'
      close/db X!databaseName!.USER err=$continue
      open/db X!databaseName!.USER intent=read wait=no err=ddbErr
   end_if

   * get view characteristics
   find viewd where mvnm='!modelName!.!viewName!' end result=no
   acquire/pv members n1=memberCount
   if memberCount=0
      put/f fid=* 'No such view'
      jump prcEnd
   end_if
   get/v [0,1]viewd intent=read
   assign/pv source=source
   set/gv viewSource=source
   find recd where recnm='!source!' end result=no
   get/v [0,1]recd intent=read
   assign/pv style=style
   * C=Conventional,D=Continuous document,S=Sectioned document
   set/gv viewIsConventional='N'
   set/gv viewIsContinuous='N'
   set/gv viewIsSectioned='N'
   if style='C'
      set/gv viewIsConventional='Y'
      set/gv viewStyle='Conventional'
   else_if style='D'
      set/gv viewIsContinuous='Y'
      set/gv viewStyle='Continuous'
    else_if style='S'
      set/gv viewIsSectioned='Y'
      set/gv viewStyle='Sectioned'
    end_if

   * get fields characteristics
   find ved where mvenm='!modelName!.!viewName!.'* and kind='EI' +
       order by mvenm end result=no
   acquire/pv members n1=fieldNE
   set/gv fieldNE=fieldNE
   set/gv viewUniqueField='' 
 
   set/gv viewStreamField=''

   for i=1,fieldNE
      * get field details
      get/v [0,i]ved intent=read
      assign/pv mvenm=mvenm
      assign/pv source=source
      set/gv fieldName!i!=$item(3,'.',mvenm)
      set/gv fieldSource!i!=$item(2,'.',source)
      get/v [renms='!source!']red
      assign/pv dt=dt
      * I=Integer, R=Real, D=Double, K=Cell, C=Character, E=exact_binary,
      * P=exact_decimal, A=approximate, X=complex, L=logical, B=byte_string
      *put/f fid=* fieldName!i! ' dt: ' dt
      set/gv fieldDataType!i!=dt
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
      set/gv fieldMinOcc!i!=minocc
      set/gv fieldMaxOcc!i!=maxocc
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

      * get index information, if any
      * please note that this script does not include the MFI indexes as they are not
      * bound to a field
      get/v [name='!source!']indxd, err=noIndxd
      * Y=Yes, N=No
      assign/pv detail=detail
      assign/pv fldlst=fldlst
      * U=Unique, E=Exact, I=Inclusive, C=Catalog, 
      * X=Extended catalog 
      assign/pv it=it
      * C=$CONCAT, B=$COMBINE, F=Field, R=Regular
      assign/pv mfityp=mfityp
      assign/pv name=name
      set/gv fieldIndexType!i!=it
      set/gv fieldMfiType!i!=mfityp
      jump hasIndxd
noIndxd:
      set/gv fieldIndexType!i!='-'
      set/gv fieldMfiType!i!='-'
hasIndxd:
      if trace = 'YES'
         put/f fid=* '>>>>> FIELD ' fieldName!i! ' dataType:' fieldDataType!i! ' isChar:' fieldIsChar!i! ' length:' fieldLength!i! +
            ' hasSubfields:' fieldHasSubfields!i! ' fieldMinOcc:' fieldMinOcc!i! ' fieldMaxOcc:' fieldMaxOcc!i! +
            ' isDate:' fieldIsDate!i! ' isLogical:' fieldIsLogical!i! ' isVirtual:' when!i! ' indexType:' fieldIndexType!i! +
            ' fieldSource:' fieldSource!i!
      end_if
   end_for

   if openCloseDdb='YES'
      close/db X!databaseName!.USER err=$continue
   end_if

   if trace = 'YES'
      put/f fid=* '>>>>> VIEW ' viewName ' isConventional:' viewIsConventional +
         ' isContinuous:' viewIsContinuous ' isSectioned:' viewIsSectioned +
         ' uniqueField:' viewUniqueField ' streamField:' viewStreamField +
         ' viewSource:' viewSource ' fieldNE:' fieldNE
   end_if

   if viewIsContinuous='Y'
      put/f fid=* 'Note : CONTinous view'
   else_if viewIsSectioned='Y'
      put/f fid=* 'Note : SECTioned view'
   end_if

   if virtualFieldsList<>'' and trace = 'YES'
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
   close/db !X!databaseName!.USER err=$continue
   put/f fid=* 'Error in getViewFieldsInfo, abort'
   set/gv getViewFieldsInfoRC=-2
   return
