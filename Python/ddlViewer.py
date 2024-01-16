#!/opt/local/bin/python
# -*- coding: UTF-8 -*-
#
# ddlViewer - visualize a Basis DDL as a treeList, by default use encoding "ISO-8859-1" (Latin 1)
# created : marcel.bechtiger@domain-sa.ch - 20230729
# modified : 20231107
# usage :
#

import wx
import os

ddlViewerVersion = "DDL Viewer v. 2023-11-07"
ddlLines = []
encoding = "ISO-8859-1"
# encoding = "UTF-8"

class MyFrame(wx.Frame):

    def __init__(self, *args, **kwds):

        kwds["style"] = kwds.get("style", 0) | wx.DEFAULT_FRAME_STYLE
        wx.Frame.__init__(self, *args, **kwds)
        self.SetSize((1000, 600))
        self.SetTitle(ddlViewerVersion)
        print("Default encoding set to", encoding)

        # menu bar
        mainMenu = wx.Menu()
        mainMenu.Append(1, "&Open")
        encodingMenu = wx.Menu()
        encodingMenu.Append(21, "ISO-8859-1")
        encodingMenu.Append(22, "UTF-8")
        mainMenu.AppendSubMenu(encodingMenu, "&Encoding")
        mainMenu.AppendSeparator()
        mainMenu.Append(3, "&About")
        mainMenu.AppendSeparator()
        mainMenu.Append(4, "E&xit")
        menuBar = wx.MenuBar()
        menuBar.Append(mainMenu, "Menu")
        self.SetMenuBar(menuBar)
        self.Bind(wx.EVT_MENU, self.onOpen, id=1)
        self.Bind(wx.EVT_MENU, self.onEncoding_ISO88591, id=21)
        self.Bind(wx.EVT_MENU, self.onEncoding_UTF8, id=22)
        self.Bind(wx.EVT_MENU, self.onAbout, id=3)
        self.Bind(wx.EVT_MENU, self.onQuit, id=4)

        # status bar
        self.CreateStatusBar()

        # vertically split window
        self.mainWindow = wx.SplitterWindow(self, wx.ID_ANY, size = (700,300))
        self.mainWindow.SetMinimumPaneSize(20)

        # tree where the entire ddlwill be displayed
        self.ddlEntries = wx.TreeCtrl(self.mainWindow, wx.ID_ANY)
        self.root = self.ddlEntries.AddRoot("top")
        self.Bind(wx.EVT_TREE_ITEM_ACTIVATED, self.OnActivated, self.ddlEntries)

        ## display some test hierarchy
        '''
        testItems = [
            ["LEVEL_1",
                ["LEVEL_1_1"]],
            ["LEVEL_2",
                ["LEVEL_2_1",
                "LEVEL_2_2",
                "LEVEL_2_3",
                ["LEVEL_2_4", ["LEVEL_2_4_1", "LEVEL_2_4_2", "LEVEL_2_4_3"]],
                "LEVEL_2_5"]
            ]
        ]
        self.addTreeNodes(self.root, testItems)
        self.ddlEntries.CollapseAllChildren(self.root)
        '''

        # text where the ddl entry's detail wil be displayed
        self.ddlEntry = wx.TextCtrl(self.mainWindow,
            style = wx.TE_MULTILINE | wx.TE_BESTWRAP | wx.TE_READONLY, value = "")

        self.mainWindow.SplitVertically(self.ddlEntries, self.ddlEntry)

        self.Layout()

    # encoding menu option
    def setEncoding(self, value):
        encoding = value
        print("Set encoding to", encoding, "for reading next DDL")
        self.SetStatusText("Set encoding to " + encoding + " for reading next DDL")
        return()

    def onEncoding_UTF8(self, event):
        self.setEncoding("UTF-8")

    def onEncoding_ISO88591(self, event):
        self.setEncoding("ISO-8859-1")

    # quit menu option
    def onQuit(self, event):
        self.Close()

    # about menu option
    def onAbout(self, event):
        wx.MessageBox(
'''
Provides an easier way to visualize/browse a LCS DDL file in a tree view where the main paragraphs are
Actual Data Model, User Data Model and Structural Data Model.

The selected topic is displayed right in the text area.

marcel.bechtiger@domain-sa.ch
www.domain-sa.ch
''', "DDL Viewer", wx.OK, self)

    # file menu option
    def onOpen(self, event):
        '''
        open file dialog to select ddl,
        concatenate lines (normally ending in ;) to reform entry,
        ddl topics are 2 forms : the short tree label and the long text
        '''
        # clear text entry if any left from previous ddl
        self.ddlEntry.SetValue("")

        openFileDialog = wx.FileDialog(self, "Open DDL file",
        defaultDir = "", defaultFile = "tour.ddl",
        wildcard = "DDL files (*.ddl)|*.ddl",
        style = wx.FD_OPEN | wx.FD_FILE_MUST_EXIST)
        if openFileDialog.ShowModal() == wx.ID_CANCEL:
            return
        else:
            ddlFileName = openFileDialog.GetPath()
            self.SetStatusText(ddlFileName)

            # frame title set to filename
            self.SetTitle(os.path.basename(ddlFileName))
            ddlLines = self.loadDdlFile(ddlFileName)

            self.ddlEntries.DeleteChildren(self.root)

            # append ddl ddlEntries
            ddlItems = self.buildDdlItems(ddlLines)
            # 1) display all raw entries (debug) or
            ##self.addTreeNodes(self.root, ddlItems)
            # 2) display shortened topics
            ddlTopics = self.buildDdlTree(ddlItems)
            #self.ddlEntries.ExpandAllChildren(self.root)
            self.ddlEntries.CollapseAllChildren(self.root)
            self.ddlEntries.Expand(self.root)

            self.SetStatusText("DDL " + ddlFileName + " contains " +
                str(len(ddlLines)) + " lines and " +
                str(len(ddlItems)) + " entries")
        openFileDialog.Destroy()

    # item selected in tree
    def OnActivated(self, evt):
        '''
        copy selected treectl item's item DATA (not displayed TEXT)
        to text area
        '''
        self.ddlEntries.Expand(evt.GetItem())
        s = self.ddlEntries.GetItemData(evt.GetItem())
        #s = self.ddlEntries.GetItemText(evt.GetItem())
        #print('Double clicked on', s, type(s), len(s))
        # revl eol were removed prior
        if not s.startswith("REVL"):
            s = s.replace("+", "+\n")
        self.ddlEntry.SetValue(s)

    # support functions
    def addTreeNodes(self, parentItem, items):
        for item in items:
            if type(item) == str:
                self.ddlEntries.AppendItem(parentItem, item)
            else:
                newItem = self.ddlEntries.AppendItem(parentItem, item[0])
                self.addTreeNodes(newItem, item[1])

    def loadDdlFile(self, ddlFileName):
        '''
        read all ddl lines to ddlLines list
        '''
        print("Reading", ddlFileName, "with encoding", encoding)
        self.SetStatusText("Reading " + ddlFileName + " with encoding " + encoding)
        try:
            with open(ddlFileName, 'r', encoding=encoding) as f:
                ddlLines = f.read().splitlines()
        except IOError:
            print("Cannot open file", ddlFileName)
            return []
        print("Closing", ddlFileName)
        print("loadDdlFile", len(ddlLines), "ddl lines")
        return ddlLines

    def buildDdlItems(self, ddlLines):
        '''
        concatenate ddl lines to form ddl entry - ";" terminated
        handle revl exception where revl contains paragraphs and
        lines are not always ";" terminated
        '''
        ddlItems = []
        ddlItem = ""
        inRevl = False
        for l in ddlLines:
            #print("<<" + l)
            l = l.lstrip(" ")
            # ignore comment lines
            if l.startswith("*"):
                continue
            else:
                # handle inline comments
                l = l.split("*")[0].strip(" ")
                # REVL paragraphs contain lines ending in ;
                if l.upper().startswith("REVL"):
                    inRevl = True
                elif l.upper().startswith("END_REVL"):
                    inRevl = False
                # revl contains proper eol that were removed earliers
                if inRevl:
                    ddlItem += l + "\n"
                elif not inRevl and l.endswith(";"):
                    ddlItem += l
                    ddlItems.append(ddlItem)
                    #print(">>" + ddlItem)
                    ddlItem = ""
                else:
                    ddlItem += l
                    #print(">>>>>" + ddlItem)
        print("buildDdlItems", len(ddlLines), "ddl lines")
        return ddlItems

    def buildDdlTree(self, ddlItems):
        '''
        build hierarchical tree with items in adm/udm/sdm
        '''
        # FIELD & FIELD_LIST appears in ADM and in UDM
        inRecord = False
        inView = False
        for entryFullText in ddlItems:
            entryShortText = self.makeShort(entryFullText)
            # ADM
            if entryShortText.startswith("ACTUAL_DATA_MODEL"):
                current, adm = self.appendEntry(self.ddlEntries, self.root,
                entryShortText, entryFullText)
                wx.TreeCtrl.SetItemBold(self.ddlEntries, current, True)
            elif entryShortText.startswith("RECORD="):
                current, record = self.appendEntry(self.ddlEntries, adm,
                entryShortText, entryFullText)
                inRecord = True
                inView = False
            elif entryShortText.startswith("FIELD=") and inRecord:
                current, recordField = self.appendEntry(self.ddlEntries, record,
                entryShortText, entryFullText)
            elif entryShortText.startswith("WORD_LIST="):
                current, wordList = self.appendEntry(self.ddlEntries, adm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("CODE_LIST="):
                current, codeList = self.appendEntry(self.ddlEntries, adm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("FIELD_LIST=") and inRecord:
                current, recordFieldList = self.appendEntry(self.ddlEntries, adm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("THESAURUS_DATA_CONTROL_SET="):
                current, thesaurusDataControlSet = self.appendEntry(self.ddlEntries, adm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("SEARCH_CONTROL_SET="):
                current, searchControlSet = self.appendEntry(self.ddlEntries, adm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("DOMAIN="):
                current, domain = self.appendEntry(self.ddlEntries, adm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("PARAMETER_SET="):
                current, parameterSet = self.appendEntry(self.ddlEntries, adm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("ASSERT"):
                current, admAssert = self.appendEntry(self.ddlEntries, adm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("REVL"):
                current, revl = self.appendEntry(self.ddlEntries, adm,
                entryShortText, entryFullText)
            # UDM
            elif entryShortText.startswith("USER_DATA_MODEL"):
                current, udm = self.appendEntry(self.ddlEntries, self.root,
                entryShortText, entryFullText)
                wx.TreeCtrl.SetItemBold(self.ddlEntries, current, True)
            elif entryShortText.startswith("MODEL="):
                current, model = self.appendEntry(self.ddlEntries, udm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("VIEW="):
                current, view = self.appendEntry(self.ddlEntries, model,
                entryShortText, entryFullText)
                inRecord = False
                inView = True
            elif entryShortText.startswith("FIELD=") and inView:
                current, viewField = self.appendEntry(self.ddlEntries, view,
                entryShortText, entryFullText)
            elif entryShortText.startswith("FIELD_LIST=") and inView:
                current, viewFieldList = self.appendEntry(self.ddlEntries, model,
                entryShortText, entryFullText)
            elif entryShortText.startswith("AT("):
                current, at = self.appendEntry(self.ddlEntries, view,
                entryShortText, entryFullText)
            # SDM
            elif entryShortText.startswith("STRUCTURAL_DATA_MODEL"):
                current, sdm = self.appendEntry(self.ddlEntries, self.root,
                entryShortText, entryFullText)
                wx.TreeCtrl.SetItemBold(self.ddlEntries, current, True)
            elif entryShortText.startswith("FILE"):
                current, file = self.appendEntry(self.ddlEntries, sdm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("AREA"):
                current, file = self.appendEntry(self.ddlEntries, sdm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("BACKUP_SET"):
                current, backupSet = self.appendEntry(self.ddlEntries, sdm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("JOURNAL"):
                current, journal = self.appendEntry(self.ddlEntries, sdm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("RECORD_STORAGE"):
                current, recordStorage = self.appendEntry(self.ddlEntries, sdm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("DDB_JOURNAL"):
                current, ddbJournal = self.appendEntry(self.ddlEntries, sdm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("DEFINITION_DATA_BASE"):
                current, definitionDataBase = self.appendEntry(self.ddlEntries, sdm,
                entryShortText, entryFullText)
            elif entryShortText.startswith("INDEX"):
                current, index = self.appendEntry(self.ddlEntries, sdm,
                entryShortText, entryFullText)
            else:
                #print("append", inRecord, inView, entryShortText, "::", entryFullText)
                current, x = self.appendEntry(self.ddlEntries, current,
                entryShortText, entryFullText)
        print("buildDdlTree", len(ddlItems), "ddl items")
        return

    def appendEntry(self, treeCtl, parent, entryShortText, entryFullText):
        '''
        appent treectl entry to parent item with
        visible short and "hidden" full text
        '''
        x = treeCtl.AppendItem(parent, entryShortText) # displayed in treeCtl
        current = x
        treeCtl.SetItemData(current, entryFullText) # will be displayed in textCtl
        return current, x

    def makeShort(self, entryFullText):
        '''
        build short entry given full ddl entry
        truncate at ";+)," etc.
        handle a few entries in special format
        '''
        s1 = entryFullText.split(",")[0]
        s2 = s1.split("+")[0].strip(" ").upper()
        entryShortText = s2
        # cleanup special case entries
        if s2.startswith("INDEX="):
            entryShortText = s2.split(",")[0].split("/")[0]
        if s2.startswith("INDEX "):
            entryShortText = s2.split("=")[0]
        elif s2.startswith("ASSERT"):
            entryShortText = s2.split(")")[0].strip(" ") + ")"
        elif s2.startswith("REVL"):
            entryShortText = s2.split(";")[0]
        elif s2.startswith("AT"):
            entryShortText = s2.split(")")[0].strip(" ") + ")"
        elif s2.startswith("FILE"):
            entryShortText = s2.split("=")[0]
        elif s2.startswith("AREA"):
            entryShortText = s2.split(",")[0]
        elif s2.startswith("JOURNAL"):
            entryShortText = s2.split("=")[0]
        elif s2.startswith("DDB_JOURNAL"):
            entryShortText = s2.split("=")[0]
        elif s2.startswith("DEFINITION_DATA_BASE"):
            entryShortText = s2.split("=")[0]
        return entryShortText.strip(" ")

class MyApp(wx.App):

    def OnInit(self):
        self.ddlViewer = MyFrame(None, wx.ID_ANY, "")
        self.SetTopWindow(self.ddlViewer)
        self.ddlViewer.Show()
        return True

if __name__ == "__main__":
    app = MyApp(0)
    app.MainLoop()
