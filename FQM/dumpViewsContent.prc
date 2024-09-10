* file : dumpViewsContent.prc
* description :
*    build a list of Conventional views in the database/model using procedure "getInfo.prc"; note that Continuous/Sectioned views are ignored
*    use procedure "export_csv.prc", resp. "export_json.prc", "export_xml.prc" to export the data of each listed/non-empty view
* usage : @dumpViewsContent db='tour' model='all' format='csv'
* created :  marcel.bechtiger@domain-sa.ch - 20240910
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

   assign/host/pv hostFormat=FORMAT
   if hostFormat<>''
      set/pv format=hostFormat
   else
      if format=''
         inquire/pv format,'Enter export format (csv, json, xml)>'
      end_if
   end_if
   if $match(format,'csv.json.xml')=0
      put/f fid=* 'Invalid export format, can only be csv, json, xml'
      return
   end_if

   * get database views info (names, occurences, styles)
   @getInfo.prc db='!db!' model='!model!'
   put/f fid=* 'Database info retrieved, starting data dump of Conventional views...'
   put/f fid=* ''
   put/f fid=* ''

   * dump data for Conventional, non-empty views
   for i=1,dbInfo_viewsNE
      set/pv view=dbInfo_viewName!i!
      if dbInfo_recordStyle!i!='C'
         if dbInfo_occurences!i!<>0
            @export_!format!.prc databaseName='!db!',modelName='!model!',viewName='!view!'
         else
            put/f fid=* 'View ' view ̈́ is not Conventional and cannot be exported'
         end_if
      end_if
      put/f fid=* ''
      put/f fid=* ''
   end_for

   return
   *exit
