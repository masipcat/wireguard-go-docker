package main

import (
	"bufio"
	"io"
	"net"
	"os"
	"strings"
)

func isLinkUp(interfaceName string) bool {
	content, err := os.ReadFile("/sys/class/net/" + interfaceName + "/carrier")
	if err != nil {
		return false
	}
	return strings.TrimSpace(string(content)) == "1"
}

func handleConnection(conn net.Conn) {
	defer conn.Close() // Ensure each connection is closed after handling

	// Read the request (we don't need to parse it for this simple healthcheck)
	bufio.NewReader(conn).ReadString('\n')

	status := "KO"
	statusCode := "503 Service Unavailable"
	if isLinkUp("wg0") {
		status = "OK"
		statusCode = "200 OK"
	}

	// Write HTTP response
	io.WriteString(conn, "HTTP/1.1 "+statusCode+"\r\n")
	io.WriteString(conn, "Content-Type: text/plain\r\n")
	io.WriteString(conn, "\r\n")
	io.WriteString(conn, "status: "+status+"\n")
}

func main() {
	port := "8080" // Default port
	if envPort := os.Getenv("HEALTHCHECK_PORT"); envPort != "" {
		port = envPort
	}

	listener, err := net.Listen("tcp", ":"+port)
	if err != nil {
		os.Stderr.WriteString("Failed to start server: " + err.Error() + "\n")
		os.Exit(1)
	}
	defer listener.Close()

	// Accept new connections and handle each in a separate goroutine
	for {
		conn, err := listener.Accept()
		if err != nil {
			continue // If accept fails, continue to next connection
		}
		go handleConnection(conn)
	}
}
