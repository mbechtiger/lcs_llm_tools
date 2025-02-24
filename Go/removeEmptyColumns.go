/*
removeEmptyColumns.go - remove empty columns from CSV file
usage : ./removeEmptyColumns -input IN -output OUT
note :
  - I couln't use the standard package "encoding/csv" for reading because it gets confused by
    the CSV dumped by HVU when subfields are quoted (as in ...#"subfield";subfield;...#...)
  - HVU does correctly that quotes (") are doubled ("") when the column contains one
  - the discrepancy when comparing column counts from the header line and from data lines is
    due to the column containing a columnDelimiter (#); in those cases, HVU did properly quote the
    field/subfield (as in ...#".........#....."#...). Below, the quoted column delimiter gets replaced
    by some new character
  - the easiest fix would most probably to use a HVU column delimiter that will not exist in the data, .e.g. "|"
created : marcel.bechtiger@domain-sa.ch 20250210
modified : 20250212
*/

package main

import (
	"bufio"
	"encoding/csv"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"time"
)

func pressEnterToContinue() {
	consoleReader := bufio.NewReader(os.Stdin)
	fmt.Print("press [Enter] to continue or [q] to quit : ")
	s, _ := consoleReader.ReadString('\n')
	s = strings.Trim(s, "\n")
	s = strings.ToLower(s)
	if s == "q" {
		fmt.Println("process interrupted by user")
		os.Exit(1)
	}
}

func main() {

	const VERSION = 20250212

	records := make([][]string, 0)
	columnNames := make([]string, 0)
	rowCount := 0
	columnsNamesNE := 0
	columnsNE := 0
	emptyColumnsCount := 0
	incorrectColumnsCount := 0

	// command line flags for input and output
	inputFile := flag.String("input", "", "input CSV file")
	outputFile := flag.String("output", "", "output CSV file")
	i1 := flag.Int("keyColIdx", 0, "key column index (1 is first column)")
	i2 := flag.Int("trace", 0, "trace level")
	i3 := flag.Int("firstRec", 0, "first record to treat")
	i4 := flag.Int("lastRec", 0, "last record to treat")
	s1 := flag.String("colDelim", "#", "column delimiter")
	s2 := flag.String("quotedColDelim", "$", "quoted column delimiter")
	flag.Parse()
	keyColIdx := *i1
	trace := *i2
	firstRecordNumber := *i3
	lastRecordNumber := *i4
	columnDelimiter := *s1
	quotedColumnDelimiter := *s2

	if len(os.Args) < 2 || *inputFile == "" || *outputFile == "" ||
		firstRecordNumber < 0 || lastRecordNumber < 0 {
		fmt.Println("utility to remove empty columns from a CSV created by HVU export.")
		fmt.Println("note that the column delimiter (#) is replaced ($) when found with a quoted string.")
		fmt.Println("usage: removeEmptyColumns -input=input.csv -output=output.csv -trace=0|1|2 -keyColIdx=4",
			"colDelim=# quotedColDelim=$ firstRec=100 lastRec=999")
		os.Exit(1)
	}

	fmt.Println("removeEmptyColumns - Domain SA - v.", VERSION)
	fmt.Println("using column delimiter :", columnDelimiter)
	fmt.Println("using quoted column delimiter :", quotedColumnDelimiter)
	fmt.Println("trace level :", trace)
	fmt.Println("looking for dumped record key at column index (trace>0) :", keyColIdx)
	fmt.Println("starting treatment at record number :", firstRecordNumber)
	fmt.Println("ending treatment at record number  :", lastRecordNumber)
	start := time.Now()
	fmt.Println("started", start)

	// open input file
	file, err := os.Open(*inputFile)
	if err != nil {
		fmt.Printf("cannot open input file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)

	// ==============================================================================
	// read input CSV, using file read instead of standard csv read
	// ==============================================================================

	fmt.Println("reading input CSV :", *inputFile)

	for scanner.Scan() {

		if err := scanner.Err(); err != nil {
			fmt.Printf("error reading input file: %v\n", err)
			os.Exit(1)
		}

		rowCount++

		// only treat records firstRecordNumber-lastRecordNumber
		// note that the first row (header) must alwasy be treated
		// do not include the first row in the data rows count
		if firstRecordNumber != 0 && rowCount < firstRecordNumber+1 && rowCount > 1 {
			continue
		}
		if lastRecordNumber != 0 && rowCount > lastRecordNumber+1 {
			break
		}

		currentLine := scanner.Text()
		if trace > 2 {
			fmt.Println(rowCount, currentLine)
		}
		rec := strings.Split(currentLine, columnDelimiter)

		// header line contains column names; use dumped key to display row  count
		if rowCount == 1 {
			columnNames = rec
			columnsNamesNE = len(columnNames)
			fmt.Println(columnsNamesNE, "columns found in header line")
			if trace == 1 {
				fmt.Println(currentLine)
			}
		} else {
			if keyColIdx != 0 && trace >= 1 {
				fmt.Println("record", rowCount-1, "has key", columnNames[keyColIdx-1], "=", rec[keyColIdx-1])
			}
		}

		if err == io.EOF {
			break
		}

		columnsNE = len(rec)

		// the column count doesn't match the header line
		// that's mostly due to a columnDelimiter found within a quoted column
		// try to fix it by replacing the columnDelimiter within quotes () by some other character
		// as in [...#"...#....."#...] becomes [...#"...$....."#...]
		if columnsNE != columnsNamesNE {
			insideQuoted := false
			b := []byte(currentLine)
			for i := 0; i < len(currentLine); i++ {
				if b[i] == '"' {
					if insideQuoted {
						insideQuoted = false
					} else {
						insideQuoted = true
					}
				}
				if insideQuoted && b[i] == columnDelimiter[0] {
					b[i] = quotedColumnDelimiter[0]
				}
			}
			currentLine = string(b)

			rec = strings.Split(currentLine, columnDelimiter)
			columnsNE = len(rec)
		}

		// columns count remains in error
		if columnsNE != columnsNamesNE {
			incorrectColumnsCount++
			fmt.Println(incorrectColumnsCount, "- incorrect column count on line :", rowCount,
				", columns count :", columnsNE, "/", columnsNamesNE, ", key", columnNames[keyColIdx-1],
				"=", rec[keyColIdx-1])
			fmt.Println("")
			fmt.Println(currentLine)
			fmt.Println("")
			pressEnterToContinue()
		}

		if err != nil {
			fmt.Printf("error reading CSV: %v\n", err)
			os.Exit(1)
		}

		records = append(records, rec)
	}

	if rowCount == 0 {
		fmt.Println("input CSV has no usable row !!")
		os.Exit(1)
	}

	fmt.Println("processed", rowCount, "lines")
	fmt.Println("total of", incorrectColumnsCount, "columns with inadequate column count")

	// cannot continue as the decoding is incorrect
	if incorrectColumnsCount != 0 {
		fmt.Println("process terminated due to incorrect column counts !")
		os.Exit(1)
	}

	// ==============================================================================
	// find empty columns,
	// skipping 1st row containing column names,
	// trimming blanks in cells
	// ==============================================================================

	fmt.Println("looking for empty columns")

	numCols := len(records[0])
	emptyColumns := make([]bool, numCols)
	for col := 0; col < numCols; col++ {
		isEmpty := true
		for _, row := range records[1:] {
			cell := strings.Trim(row[col], " ")
			if col < len(row) && cell != "" {
				isEmpty = false
				break
			}
		}
		emptyColumns[col] = isEmpty
		if isEmpty {
			emptyColumnsCount++
		}
		if trace == 2 {
			fmt.Println("column", col+1, columnNames[col], "isEmpty :", emptyColumns[col])
		}
	}

	fmt.Println("found", emptyColumnsCount, "empty columns")

	// ==============================================================================
	// create new table without empty columns
	// ==============================================================================

	fmt.Println("building table without empty columns")

	newRecords := make([][]string, len(records))
	for i, row := range records {
		newRow := make([]string, 0)
		for col := 0; col < len(row); col++ {
			if !emptyColumns[col] {
				newRow = append(newRow, row[col])
			}
		}
		newRecords[i] = newRow
	}

	// ==============================================================================
	// write output CSV
	// ==============================================================================

	fmt.Println("writing output CSV :", *outputFile)

	outFile, err := os.Create(*outputFile)
	if err != nil {
		fmt.Printf("error creating output file: %v\n", err)
		os.Exit(1)
	}
	defer outFile.Close()

	writer := csv.NewWriter(outFile)
	runes := []rune(columnDelimiter)
	writer.Comma = runes[0]
	defer writer.Flush()

	err = writer.WriteAll(newRecords)
	if err != nil {
		fmt.Printf("error writing CSV: %v\n", err)
		os.Exit(1)
	}

	end := time.Now()
	fmt.Println("ended", end)
	elapsed := end.Sub(start)
	fmt.Println("duration", elapsed)
	fmt.Println("process terminated successfully !")

}
