/*
viewsJsonDescription.go - import LCS dictionary description in JSON format, created with DMFQM/viewJsonDecription.prc
usage : ./viewsJsonDescription input.json {VIEW_NAME} {FIELD_NAME}")
created : marcel.bechtiger@domain-sa.ch 20250308
modified :
*/

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
)

// Field represents each field in a view
type Field struct {
	Entry   int    `json:"entry"`
	Name    string `json:"name"`
	Source  string `json:"source"`
	Type    string `json:"type"`
	Usage   string `json:"usage"`
	Len     string `json:"len"`
	OccMin  int    `json:"occMin"`
	OccMax  int    `json:"occMax"`
	Virtual string `json:"virtual"`
	IsDate  string `json:"isDate"`
	IdxType string `json:"idxType"`
}

// Fields is a map of field name to Field
type Fields map[string]Field

// View represents a database view
type View struct {
	Entry       int    `json:"entry"`
	Name        string `json:"name"`
	Source      string `json:"source"`
	Style       string `json:"style"`
	UniqueField string `json:"uniqueField"`
	StreamField string `json:"streamField"`
	FieldsNE    int    `json:"fields_ne"`
	Fields      Fields `json:"fields"`
}

// Views is a map of view name to View
type Views map[string]View

// DatabaseSchema is the top level structure
type DatabaseSchema struct {
	Database    string `json:"database"`
	Model       string `json:"model"`
	FileCreated string `json:"created"`
	ViewsNE     int    `json:"views_ne"`
	Views       Views  `json:"views"`
}

// Retrieve a specific view.field
func (schema *DatabaseSchema) GetField(view View, fieldName string) (Field, bool) {

	// Check if field exists in the view
	field, fieldExists := view.Fields[fieldName]
	if !fieldExists {
		return Field{}, false
	}

	return field, true
}

// Dump a field description
func PrintField(field Field) {
	fmt.Printf("  Field: %s\n", field.Name)
	fmt.Printf("    Entry: %d\n", field.Entry)
	fmt.Printf("    Source: %s\n", field.Source)
	fmt.Printf("    Type: %s\n", field.Type)
	fmt.Printf("    Usage: %s\n", field.Usage)
	fmt.Printf("    Len: %s\n", field.Len)
	fmt.Printf("    Occurs Min: %d\n", field.OccMin)
	fmt.Printf("    Occurs Max: %d\n", field.OccMax)
	fmt.Printf("    Is Virtual: %s\n", field.Virtual)
	fmt.Printf("    Is Date: %s\n", field.IsDate)
	fmt.Printf("    Index Type: %s\n", field.IdxType)
}

// Dump a view description
func PrintView(view View) {
	fmt.Printf("View: %s\n", view.Name)
	fmt.Printf("  Entry: %d\n", view.Entry)
	fmt.Printf("  Source: %s\n", view.Source)
	fmt.Printf("  Style: %s\n", view.Style)
	fmt.Printf("  Unique Field: %s\n", view.UniqueField)
	fmt.Printf("  Stream Field: %s\n", view.StreamField)
	fmt.Printf("  Number of Fields: %d\n", view.FieldsNE)
}

// Read/load JSON dictionary
func readJsonFile(fileName string) (DatabaseSchema, bool) {

	var schema DatabaseSchema

	// Read file
	data, err := os.ReadFile(fileName)
	if err != nil {
		log.Fatalf("Error reading file: %v", err)
		return schema, false
	}

	// get error "Error parsing JSON: invalid character 'ï' looking for beginning of value" if this is not added ?!
	data = bytes.TrimPrefix(data, []byte("\xef\xbb\xbf"))
	//s := string(data[:])
	//fmt.Println(s)

	// Parse JSON
	err = json.Unmarshal(data, &schema)
	if err != nil {
		log.Fatalf("Error parsing JSON: %v", err)
		return schema, false
	}
	return schema, true
}

// Dump views/fields in dictionary
func dumpAllViews(schema *DatabaseSchema) {

	fmt.Printf("Database: %s\n", schema.Database)
	fmt.Printf("Model: %s\n", schema.Model)
	fmt.Printf("File Created: %s\n", schema.FileCreated)
	fmt.Printf("Number of Views: %d\n\n", schema.ViewsNE)

	// Iterate through views
	for _, view := range schema.Views {
		PrintView(view)

		// Iterate through fields
		for _, field := range view.Fields {
			PrintField(field)
		}
		fmt.Println()
	}
}

// Dump views/fields in dictionary
func dumpOneView(schema *DatabaseSchema, viewName string) {

	view, viewExists := schema.Views[viewName]
	if !viewExists {
		fmt.Printf("View '%s' not found.\n", viewName)
		return
	}

	PrintView(view)

	// Iterate through fields
	for _, field := range view.Fields {
		PrintField(field)
	}
	fmt.Println()

}

// Dump one view.field
func dumpOneViewField(schema *DatabaseSchema, viewName string, fieldName string) {

	view, viewExists := schema.Views[viewName]
	if !viewExists {
		fmt.Printf("View '%s' not found.\n", viewName)
		return
	}

	PrintView(view)

	field, found := schema.GetField(view, fieldName)
	if found {
		PrintField(field)
	} else {
		fmt.Printf("Field '%s' in view '%s' not found.\n", fieldName, viewName)
		return
	}
}

func main() {

	log.Println("Begin")

	// Check if filename is provided
	if len(os.Args) < 2 {
		log.Fatal("Usage: go run viewsJsonDescription.go fileName.json {VIEW_NAME} {FIELD_NAME}")
	}

	filename := os.Args[1]

	// Load JSON dictionary
	schema, fileParsed := readJsonFile(filename)
	if !fileParsed {
		log.Fatal("Abnormal termination")
		return
	}

	// If view.field names are provided, dump specific field
	if len(os.Args) >= 4 {
		viewName := strings.ToUpper(os.Args[2])
		fieldName := strings.ToUpper(os.Args[3])
		dumpOneViewField(&schema, viewName, fieldName)
		log.Println("OneViewField - Normal termination")
		return
	}

	// If view name are provided, dump specific view/fields
	if len(os.Args) >= 3 {
		viewName := strings.ToUpper(os.Args[2])
		dumpOneView(&schema, viewName)
		log.Println("OneView - Normal termination")
		return
	}

	// Otherwise dump all information
	dumpAllViews(&schema)
	log.Println("AllViews - Normal termination")
}
