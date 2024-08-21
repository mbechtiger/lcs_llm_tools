## LCS Tools repository

Livelink Collections Server (LCS) is a product from Open Text Inc. (www.opentext.com) used to store and index office documents. Besides being a relational DBMS, LCS natively handles full text searching and thesaurus relations during validation/retrieval.

Livelink Library Management (LLM) is a library and documentation center data management application built on top of LCS, hence the same export tools apply to LLM and LCS.

I have been involved in many LCS/LLM data extraction and migration projects, some of the tools I developed are made available here.

The tools can be used with any version of LCS resp. LLM as they are based on the module DMFQM to query the data dictionary and database, dump files produced in "stream" format with the module DMHVU, and DDL files produced by the DMDDBE module. The 3 programs are included in the base LCS system.

The repository contains programs written in LCS proprietary module DMFQM, Python and Go to :
- explore the LCS data dictionary definition for a view, to provide insight prior to the export (uses DMFQM)
- export data from LCS to CSV - any output format can be implemented (uses DMFQM)
- reformat/convert files exported with LCS proprietary module DMHVU (in Stream format) to CSV/XML/JSON (usiusesng Python)
- visualize a LCS Data Definition Language (DDL) file exported with LCS proprietary module DMDDBE using a tree-view (uses Python+wxpython)
- remove a column from any CSV export file (uses Python+Pandas+csv)
- list the fields referenced in a dump file created with the LCS DMHVU module in Stream format (uses Go)

The repository contains sub-folders :
- FQM : 
	- "getInfo.prc" and "export_csv.prc"/"export_json.prc", "export_xml.prc" calling "getViewFieldsInfo.prc"
- Python : 
	- "ddlViewer.py" and sample DDL "tour.ddl" & "dossbas.ddl"
	- "hvuConvert.py", sample dump files "tour_employee.dmp" & "tlpfra_cat.dmp"
	- "removeCsvColumn.py"
- Go : 
	- "hvuStreamListFields.go", sample dump files "tour_employee.dmp" & "tlpfra_cat.dmp"

Comments at the beginning of each program provides a description and sample usage, and should be sufficient to use the tool.

More tools may be added, upon request by you ! I'm currently thinking about utilities to migrate tables (structure and data) from LCS to ElasticSearch, PostgreSQL, Apache Solr.

Contact me at marcel.bechtiger@domain-sa.ch.
