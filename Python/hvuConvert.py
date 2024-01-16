#! /opt/local/bin/python

''' hvuConvert : convert LCS hvu stream formated file to JSON/XML/CSV or provide field stats
usage : python hvuConvert.py -i file.dmp -o file.out -a toJson|toXml|toCsv|stats|cstats -e UTF-8
created : marcel.bechtiger@domain-sa.ch - 20231026
modified :
'''

import getopt, sys
from datetime import datetime
import json
import xmltodict
import csv

# counts of occurence for each field
fieldCounts = {}
# trace records every.. and lines every..*50
traceEvery = 10000
# csv delimiter, if used
csvColDelimiter = "#"

########## functions ##########

def printUsage():
    print("usage : hvuConvert.py --in=file.dmp {--out=file.out} --action=toJson|toXml|toCsv|{stats}|cstats {--encoding=UTF-8}")
    print("or      hvuConvert.py -i file.dmp {-o file.out} -a toJson|toXml|toCsv|{stats}|cstats {-e UTF-8}")
    print("        file.dmp must be in LCS hvu stream format, file.out will be Json or Xml or Csv or")
    print("        stats - sort by field name, cstats - sort by reverse occurence")
    print("        default is : stats on input file, ISO-8859-1 encoding")
    print("        popular encodings are UTF-8, ISO-8859-1 (Latin-1)")

def getArguments():
    # get execution arguments
    argumentList = sys.argv[1:]
    options = "hi:o:a:e:"
    longOptions = ["help", "in=", "out=", "action=", "encoding="]
    inFile = outFile = ""
    action = "stats"
    # mostly used with Windows dumps
    encoding = "ISO-8859-1"
    try:
        arguments, values = getopt.getopt(argumentList, options, longOptions)
        for a, v in arguments:
            if a in ("-h", "--help"):
                printUsage()
            elif a in ("-i", "--in"):
                inFile = v
            elif a in ("-o", "--out"):
                outFile = v
            elif a in ("-a", "--action"):
                action = v
            elif a in ("-e", "--encoding"):
                encoding = v
            else:
                printUsage()
        print("using encoding:", encoding)
    except getopt.error as err:
        print (str(err))
        exit(1)
    return(inFile, outFile, action, encoding)

def openInFile(inFile, encoding):
    # open hvu stream input file
    try:
        inF = open(inFile, "r", encoding=encoding)
    except Exception as e:
        print("cannot open inFile")
        print (str(e))
        exit(1)
    return(inF)

def openOutFile(outFile, encoding):
    # open json/xml output file
    try:
        outF = open(outFile, 'w', encoding=encoding)
    except Exception as e:
        print("cannot open outFile")
        print (str(e))
        exit(1)
    return(outF)

def getRecordName(line):
    recordName = line[3:32].strip()
    #print("recordName:", recordName)
    return(recordName)

def getFieldNameStats(line):
    line = line[3:]
    fieldName = line.split("(")[0]
    #print("fieldName:", fieldName)
    if fieldCounts.get(fieldName, 0) == 0:
        fieldCounts[fieldName] = 1
    else:
        fieldCounts[fieldName] += 1
    return(fieldName)

def getFieldData(line):
    line = line[3:]
    fieldName = line.split("(")[0]
    s = line.split("(")[1].split(")")[0]
    fieldOcc = int(s)
    #print("fieldName:", fieldName, "fieldOcc:", fieldOcc)
    return(fieldName, fieldOcc)

def doStats(inF, action, encoding):
    # read hvu stream and count record/field names
    countOfR = countOfV = countOfK = countOfE = countOfL = countOfD = countOfC = countOfUndef = 0
    recordName = fieldName = ""
    lineCount = 0
    try:
        while line := inF.readline():
            lineCount += 1
            if lineCount % (traceEvery * 50) == 0:
                print("{0:,} lines".format(lineCount))
            if len(line) < 3:
                #print("short line", len(line), lineCount, line)
                countOfUndef += 1
                next
            line = line.rstrip()
            #print("line:", line)
            lineCode = line[0:1]
            match lineCode:
                # R  EMPLOYEE                            <<< record # 2 >>>
                case "R":
                    countOfR += 1
                    recordName = getRecordName(line)
                # V  COMM(1)=400.00
                case "V":
                    countOfV += 1
                    fieldName = getFieldNameStats(line)
                # K  keyValue
                case "K":
                    countOfK += 1
                # E  DISPLAY_TI(1)
                case "E":
                    countOfE += 1
                    fieldName = getFieldNameStats(line)
                # L70La monnaie et...
                case "L":
                    countOfL += 1
                # D  La monnaie et...
                case "D":
                    countOfD += 1
                # C...comment
                case "C":
                    countOfC += 1
                case _:
                    countOfUndef += 1
                    #print("unexpected line at:", lineCount, line)
    except Exception as e:
        print("read error, line", lineCount)
        print("try using another encoding, used", encoding)
        abnormalTermination()
    # print stats
    print("*** {0:,} lines in input file".format(lineCount))
    s = '''*** countOfR: {0:,} countOfV: {1:,} countOfK: {2:,} countOfE: {3:,} countOfL: {4:,}
    countOfD: {5:,} countOfC {6:,} countOfUndef: {7:,}'''
    print(s.format(countOfR, countOfV, countOfK, countOfE, countOfL, countOfD, countOfC, countOfUndef))

    # sort by key
    if action == "stats":
        sortedFieldCounts = dict(sorted(fieldCounts.items()))
    # sort by value
    else:
        sortedFieldCounts = dict(sorted(fieldCounts.items(), key=lambda item: item[1], reverse=True))
    print("*** stats of (non-null) referenced fields counts:")
    for k in sortedFieldCounts.keys():
        print("{0} [{1:,}]".format(k, sortedFieldCounts[k]))
    return()

def isInt(s):
    try:
        return(int(s))
    except:
        return("")

def isFloat(s):
    try:
        return(float(s))
    except:
        return("")

def setValueType(s):
    if s != "":
        v = isInt(s)
        if v != "":
            return(v)
        v = isFloat(s)
        if v != "":
            return(v)
    return(s)

def appendToFieldBuffer(previousFieldName, fieldValue, subfieldfList):
    # json array is an [e1, ..., en] list
    if previousFieldName == "" or fieldValue == "":
        return()
    v = setValueType(fieldValue)
    subfieldfList.append(v)
    return()

def appendToFieldsDict(fieldName, subfieldList, fieldsDict):
    if len(subfieldList) > 1:
        fieldsDict[fieldName] = subfieldList
    elif len(subfieldList) == 1:
        fieldsDict[fieldName] = subfieldList[0]
    subfieldList = []
    return()

def getRecordDictionary(inF, recordCount, recordName):
    # read hvu stream and return one record occurenca as dictionary
    recordDict, fieldsDict = {}, {}
    subfieldList = []
    fieldName = previousFieldName = fieldValue = ""
    fieldOcc = previousFieldOcc = lineCount = 0
    #print("recordCount:", recordCount)

    # beware that some hvu lines migt be crap, aka ending with ^M
    # handle short lines
    while line := inF.readline():
        if len(line) < 3:
            #print("short line", len(line), line)
            next
        line = line.rstrip()
        lineCount += 1
        lineCode = line[0:1]
        match lineCode:
            # R  EMPLOYEE                            <<< record # 1 >>>
            case "R":
                recordName = getRecordName(line)
                # dump previous record, if any
                if lineCount > 1:
                    appendToFieldBuffer(previousFieldName, fieldValue, subfieldList)
                    appendToFieldsDict(previousFieldName, subfieldList, fieldsDict)
                    recordDict[recordName] = fieldsDict
                    return(recordName, recordDict, False)
            # V  COMM(1)=400.00
            case "V":
                appendToFieldBuffer(previousFieldName, fieldValue, subfieldList)
                fieldName, fieldOcc = getFieldData(line)
                if fieldOcc == 1:
                    appendToFieldsDict(previousFieldName, subfieldList, fieldsDict)
                    subfieldList = []
                else:
                    appendToFieldsDict(fieldName, subfieldList, fieldsDict)
                previousFieldName, previousFieldOcc = fieldName, fieldOcc
                fieldValue = line.split("=")[1]
            # ignore K, C lines
            # K  keyValue
            # C...comment...
            case "C" | "K":
                s = ""
            # E  DISPLAY_TI(1) is followeb by
            # L70La monnaie et... or
            # D  La monnaie et...
            case "E":
                appendToFieldBuffer(previousFieldName, fieldValue, subfieldList)
                fieldName, fieldOcc = getFieldData(line)
                if fieldOcc == 1:
                    appendToFieldsDict(previousFieldName, subfieldList, fieldsDict)
                    subfieldList = []
                else:
                    appendToFieldsDict(fieldName, subfieldList, fieldsDict)
                previousFieldName, previousFieldOcc = fieldName, fieldOcc
                fieldValue = ""
            case "L" | "D":
                fieldValue += line[3:]
            # some ill formated line is continued due to CR-LF in text
            case _:
                fieldValue += line
    #sortedFieldsDict = dict(sorted(fieldsDict.items()))
    #recordDict[recordName] = sortedFieldsDict
    # handle case where last line was "L" or "D"
    if fieldValue != "":
        appendToFieldBuffer(previousFieldName, fieldValue, subfieldList)
        appendToFieldsDict(previousFieldName, subfieldList, fieldsDict)
    recordDict[recordName] = fieldsDict
    return(recordName, recordDict, True)

def getFieldList(inF, encoding):
    # read hvu stream and get field names
    header = []
    lineCount = 0
    print("parse input file to get non-empty fieldlist for csv header")
    try:
        while line := inF.readline():
            lineCount +=1
            if lineCount % (traceEvery * 50) == 0:
                print("{0:,} lines".format(lineCount))
            if len(line) < 3:
                next
            line = line.rstrip()
            lineCode = line[0:1]
            match lineCode:
                # V  COMM(1)=400.00
                case "V":
                    fieldName = getFieldNameStats(line)
                # E  DISPLAY_TI(1)
                case "E":
                    fieldName = getFieldNameStats(line)
                case "R" | "K" | "L" | "D" | "C":
                    next
                case _:
                    next
    except Exception as e:
        print("read error, line", lineCount)
        print("try using another encoding, used", encoding)
        abnormalTermination()
    print("{0:,} total lines".format(lineCount))
    header = list(fieldCounts.keys())
    header.sort()
    print('***', len(header), "fields in header")
    #print(header)
    # must rewind input file
    inF.seek(0)
    return(header)

def doHvuToJson(inF, outF):
    recordCount = 0
    recordName = ""
    outF.write("{\n\"RECORDS\" : [\n")
    while True:
        recordCount +=1
        if recordCount % traceEvery == 0:
            print("{0:,} records".format(recordCount))
        recordName, recordDict, isLastRecord = getRecordDictionary(inF, recordCount, recordName)
        recordJson = json.dumps(recordDict, indent=2, sort_keys=True)
        #print(recordJson)
        if recordCount > 1:
            outF.write(",\n")
        outF.write(recordJson)
        #json.dump(recordDict, outF, indent=2, sort_keys=True)
        if isLastRecord:
            print("{0:,} total records".format(recordCount))
            break
    outF.write("\n],\n\"RECORDS_COUNT\" : %d\n}\n" % recordCount)
    return()

def doHvuToXml(inF, outF):
    recordCount = 0
    recordName = ""
    outF.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
    outF.write("\n<RECORDS>")
    while True:
        recordCount +=1
        if recordCount % traceEvery == 0:
            print("{0:,} records".format(recordCount))
        recordName, recordDict, isLastRecord = getRecordDictionary(inF, recordCount, recordName)
        #recordXml = xmltodict.unparse(recordDict, pretty=True, full_document=True, newl="\n", indent="  ")
        #print(recordXml)
        outF.write("\n")
        xmltodict.unparse(recordDict, output=outF, pretty=True, full_document=False, newl="\n", indent="  ")
        if isLastRecord:
            print("{0:,} total records".format(recordCount))
            break
    outF.write("\n</RECORDS>")
    outF.write("\n<RECORDS_COUNT>%d</RECORDS_COUNT>\n" % recordCount)
    return()

def doHvuToCsv(inF, outF, encoding):
    recordCount = 0
    recordName = ""
    # get header by reading whole file in and rewind it
    header = getFieldList(inF, encoding)
    # csv writer
    csv.register_dialect('xyz', delimiter=csvColDelimiter, quoting=csv.QUOTE_NONE,
        escapechar='\\', quotechar='\'')
    writer = csv.DictWriter(outF, fieldnames=header, dialect='xyz')
    writer.writeheader()
    while True:
        recordCount +=1
        if recordCount % traceEvery == 0:
            print("{0:,} records".format(recordCount))
        recordName, recordDict, isLastRecord = getRecordDictionary(inF, recordCount, recordName)
        noTitleRecordDict = recordDict[recordName]
        writer.writerow(noTitleRecordDict)
        if isLastRecord:
            print("{0:,} total records".format(recordCount))
            break
    return()

def getDateTimeNow():
    now = datetime.now()
    return(now.strftime("%d.%m.%Y %H:%M:%S"))

def normalTermination():
    print("*** normal termination", getDateTimeNow())
    exit(0)

def abnormalTermination():
    print("*** abnormal termination", getDateTimeNow())
    exit(1)

########## main ##########

def doMain():
    print("*** started", getDateTimeNow())

    inFile, outFile, action, encoding = getArguments()

    #print("in:", inFile, "out:", outFile, "action:", action, "encoding:", encoding)

    if inFile == "" :
        print("missing input file")
        printUsage()
        exit(2)

    if (action != "stats" and action != "cstats") and outFile == "" :
        print("missing output file")
        printUsage()
        exit(2)

    inF = openInFile(inFile, encoding)

    if action == "stats" or action == "cstats":
        doStats(inF, action, encoding)
    else:
        outF = openOutFile(outFile, encoding)
        if action == "toJson":
            doHvuToJson(inF, outF)
        elif action == "toXml":
            doHvuToXml(inF, outF)
        elif action == "toCsv":
            doHvuToCsv(inF, outF, encoding)
        else:
            print("invalid action", action)
            abnormalTermination()
        outF.close()
    inF.close()
    normalTermination()

if __name__ == "__main__":
    doMain()
