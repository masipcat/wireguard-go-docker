package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strings"
)

func isLinkUp(interfaceName string) bool {
	content, err := ioutil.ReadFile("/sys/class/net/" + interfaceName + "/carrier")
	if err != nil {
		return false
	}
	return strings.TrimSpace(string(content)) == "1"
}

func healthCheckHandler(w http.ResponseWriter, r *http.Request) {
	if isLinkUp("wg0") {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "status: OK\n")
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprintf(w, "status: KO\n")
	}
}

func main() {
	http.HandleFunc("/", healthCheckHandler)
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Printf("Failed to start server: %v\n", err)
		os.Exit(1)
	}
}
