/*
hvuStream.go - read HVU STREAM formatted dump and list FIELD occurences,
to be used to figure out which fields are actually used in the table
usage : go run hvuStream.go TOUR_EMPLOYEE.dmp
created : marcel.bechtiger@domain-sa.ch 20230120
modified :
note that the host/target OS/architecture are defined by variables
GOARCH="amd64", 386, ...
GOOS="linux", windows, darwin, linux, ...
GOHOSTARCH="amd64"
GOHOSTOS="darwin"
see https://go.dev/doc/install/source#environment for full list
*/

package main

import (
  "fmt"
  "os"
  "bufio"
  "strings"
  "sort"
  "time"
  "strconv"
)

var fieldCounts = make(map[string]int)
const DEBUG = false
const TRACE = 500000
const VERSION = 20230119

func main() {

  var line, firstChar, recordName string
  var countOfR, countOfV, countOfK, countOfE, lineCount int

  fmt.Println("hvuStream - Domain SA - v.", VERSION)
  start := time.Now()
  fmt.Println("started", start)

  if len(os.Args) < 2 {
    fmt.Println("Utility to parse an HVU stream dump and list used fields counts")
    fmt.Println("A dump file name must be provided !!")
    return
  }

  file, err := os.Open(os.Args[1])
  if err != nil {
    fmt.Println("Error opening file:", err)
    return
  }
  defer file.Close()

  fmt.Printf("info : a . is displayed every %s lines of input\n", formatInt(TRACE))

  scanner := bufio.NewScanner(file)

  for scanner.Scan() {
    line = scanner.Text()
    lineCount++
    if lineCount % TRACE == 0 { fmt.Println(".") }

    if len(line) < 3 {
      fmt.Printf("unexpected short line at line %s\n", formatInt(lineCount))
      continue
    }
    firstChar = line[0:1]
    switch firstChar {

      // R  EMPLOYEE                            <<< record # 2 >>>
      case "R": {
        countOfR++
        recordName = strings.TrimSpace(line[3:32])
        if DEBUG { fmt.Printf("<%s>\n", recordName) }
        _ = recordName
      }

      // V  COMM(1)=400.00
      case "V": {
        countOfV++
        getFieldName(line, recordName)
      }

      // ?
      case "K": {
        countOfK++
        fmt.Println(line)
      }

      // E  DISPLAY_TI(1)
      case "E": {
        countOfE++
        getFieldName(line, recordName)
      }

      // L70La monnaie et...
      case "L": {
        // ignore data lines
      }

      default: {
        fmt.Printf("unexpected line code at line %s : %s\n", formatInt(lineCount), line)
      }
    }
  }

  fmt.Printf("\n********************\ntotal of %s lines in file\n", formatInt(lineCount))
  fmt.Printf("%s RECORD, %s V FIELD, %s K FIELD, %s E FIELD lines found\n",
    formatInt(countOfR), formatInt(countOfV), formatInt(countOfK), formatInt(countOfE))

  dumpFieldCountsByKey()
  dumpFieldCountsByDescendValue()

  if err := scanner.Err(); err != nil {
    fmt.Println("Error reading file :", err)
  }

  end := time.Now()
  fmt.Println("ended", end)
  elapsed := end.Sub(start)
  fmt.Println("duration", elapsed)
}

// -------------------- functions --------------------

// extract field name from V/E line
func getFieldName (line string, recordName string) {
  fieldName := line[3:]
  i := strings.Index(fieldName, "(")
  fieldName = fieldName[0:i]
  k := recordName + "." + fieldName
  if fieldCounts[k] == 0 {
    fieldCounts[k] = 1
  } else {
    fieldCounts[k]++
  }
  if DEBUG { fmt.Printf("%s -- key=%s, count=%d\n", line, k, fieldCounts[k]) }
}

// sort map by key and print record.field occurences
func dumpFieldCountsByKey () {
  fmt.Println("***** dump Field Counts By Key (field name) *****")
  keys := make([]string, 0, len(fieldCounts))
  for k := range fieldCounts {
    keys = append(keys, k)
  }
  sort.Strings(keys)
  for _, k := range keys {
    fmt.Printf("%s occurs %s times\n", k, formatInt(fieldCounts[k]))
  }
}

// sort map by key and print record.field occurences
// https://www.geeksforgeeks.org/how-to-sort-golang-map-by-keys-or-values/
func dumpFieldCountsByDescendValue () {
  fmt.Println("***** dump Field Counts By Descend Value (occurence count)*****")
  keys := make([]string, 0, len(fieldCounts))
  for k := range fieldCounts {
    keys = append(keys, k)
  }
  // ascending: <, descending: >
  sort.SliceStable(keys, func(i, j int) bool {
    return fieldCounts[keys[i]] > fieldCounts[keys[j]]
  })
  for _, k := range keys {
    fmt.Printf("%s occurs %s times\n", k, formatInt(fieldCounts[k]))
  }
}

// https://stackoverflow.com/questions/13020308/how-to-fmt-printf-an-integer-with-thousands-comma
func formatInt64(n int64) string {
  in := strconv.FormatInt(n, 10)
  numOfDigits := len(in)
  if n < 0 {
    numOfDigits-- // First character is the - sign (not a digit)
  }
  numOfCommas := (numOfDigits - 1) / 3

  out := make([]byte, len(in)+numOfCommas)
  if n < 0 {
    in, out[0] = in[1:], '-'
  }

  for i, j, k := len(in)-1, len(out)-1, 0; ; i, j = i-1, j-1 {
    out[j] = in[i]
    if i == 0 {
      return string(out)
    }
    if k++; k == 3 {
      j, k = j-1, 0
      out[j] = '\''
    }
  }
}

// https://stackoverflow.com/questions/13020308/how-to-fmt-printf-an-integer-with-thousands-comma
func formatInt(number int) string {
  output := strconv.Itoa(number)
  startOffset := 3
  if number < 0 {
    startOffset++
  }
  for outputIndex := len(output); outputIndex > startOffset; {
    outputIndex -= 3
    output = output[:outputIndex] + "'" + output[outputIndex:]
  }
  return output
}
