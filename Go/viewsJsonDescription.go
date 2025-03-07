package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
)

// Field represents each field in a view
type Field struct {
	Entry int `json:"entry"`
	Name string `json:"name"`
	Source string `json:"source"`
	Type string `json:"type"`
	Len string `json:"len"`
	OccMin int `json:"occMin"`
	OccMax int `json:"occMax"`
	Virtual string `json:"virtual"`
	IsDate string `json:"isDate"`
	IdxType string `json:"idxType"`
}

// Fields is a map of field name to Field
type Fields map[string]Field

// View represents a database view
type View struct {
	Entry int `json:"entry"`
	Name string `json:"name"`
	Source string `json:"source"`
	Style string `json:"style"`
	UniqueField string `json:"uniqueField"`
	StreamField string `json:"streamField"`
	FieldsNE int `json:"fields_ne"`
	Fields Fields `json:"fields"`
}

// Views is a map of view name to View
type Views map[string]View

// DatabaseSchema represents the top level structure
type DatabaseSchema struct {
	Database string `json:"database"`
	Model string `json:"model"`
	FileCreated string `json:"created"`
	ViewsNE int `json:"views_ne"`
	Views Views `json:"views"`
}

// GetField retrieves a specific field from a specific view
// Returns the field and a boolean indicating if it was found
func (schema *DatabaseSchema) GetField(viewName, fieldName string) (Field, bool) {
	// Check if view exists
	view, viewExists := schema.Views[viewName]
	if !viewExists {
		return Field{}, false
	}
	
	// Check if field exists in the view
	field, fieldExists := view.Fields[fieldName]
	if !fieldExists {
		return Field{}, false
	}
	
	return field, true
}

// PrintField prints information about a specific field
func PrintField(viewName, fieldName string, field Field) {
	fmt.Printf("Field Information:\n")
	fmt.Printf("  View: %s\n", viewName)
	fmt.Printf("  Field: %s\n", fieldName)
	fmt.Printf("    Entry: %d\n", field.Entry)
	//fmt.Printf("    Name: %s\n", field.Name)
	fmt.Printf("    Source: %s\n", field.Source)
	fmt.Printf("    Type: %s\n", field.Type)
	fmt.Printf("    Len: %s\n", field.Len)
	fmt.Printf("    Occurs Min: %d\n", field.OccMin)
	fmt.Printf("    Occurs Max: %d\n", field.OccMax)
	fmt.Printf("    Is Virtual: %s\n", field.Virtual)
	fmt.Printf("    Is Date: %s\n", field.IsDate)
	fmt.Printf("    Index Type: %s\n", field.IdxType)
}

func main() {
	// Check if filename is provided
	if len(os.Args) < 2 {
		log.Fatal("Usage: go run main.go <filename> [view_name field_name]")
	}
	
	filename := os.Args[1]
	
	// Read file
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		log.Fatalf("Error reading file: %v", err)
	}

	// get error "Error parsing JSON: invalid character 'ï' looking for beginning of value" if this is not added ?
	data = bytes.TrimPrefix(data, []byte("\xef\xbb\xbf"))
	//s := string(data[:])
	//fmt.Println(s)
	
	// Parse JSON
	var schema DatabaseSchema
	err = json.Unmarshal(data, &schema)
	if err != nil {
		log.Fatalf("Error parsing JSON: %v", err)
	}
	
	// If view and field names are provided, look up that specific field
	if len(os.Args) >= 4 {
		viewName := os.Args[2]
		fieldName := os.Args[3]
		
		field, found := schema.GetField(viewName, fieldName)
		if found {
			PrintField(viewName, fieldName, field)
		} else {
			fmt.Printf("Field '%s' in view '%s' not found. Note that names are case-sensitive.\n", fieldName, viewName)
		}
		return
	}
	
	// Otherwise print all information
	fmt.Printf("Database: %s\n", schema.Database)
	fmt.Printf("Model: %s\n", schema.Model)
	fmt.Printf("File Created: %s\n", schema.FileCreated)
	fmt.Printf("Number of Views: %d\n\n", schema.ViewsNE)
	
	// Iterate through views
	for viewName, view := range schema.Views {
		fmt.Printf("View: %s\n", viewName)
		//fmt.Printf("  Name: %s\n", view.Name)
		fmt.Printf("  Entry: %d\n", view.Entry)
		fmt.Printf("  Source: %s\n", view.Source)
		fmt.Printf("  Style: %s\n", view.Style)
		fmt.Printf("  Unique Field: %s\n", view.UniqueField)
		fmt.Printf("  Stream Field: %s\n", view.StreamField)
		fmt.Printf("  Number of Fields: %d\n", view.FieldsNE)
		
		// Iterate through fields
		for fieldName, field := range view.Fields {
			fmt.Printf("  Field: %s\n", fieldName)
			fmt.Printf("    Entry: %d\n", field.Entry)
			//fmt.Printf("    Name: %s\n", field.Name)
			fmt.Printf("    Source: %s\n", field.Source)
			fmt.Printf("    Type: %s\n", field.Type)
			fmt.Printf("    Len: %s\n", field.Len)
			fmt.Printf("    Occurs Min: %d\n", field.OccMin)
			fmt.Printf("    Occurs Max: %d\n", field.OccMax)
			fmt.Printf("    Is Virtual: %s\n", field.Virtual)
			fmt.Printf("    Is Date: %s\n", field.IsDate)
			fmt.Printf("    Index Type: %s\n", field.IdxType)
		}
		fmt.Println()
	}
}

