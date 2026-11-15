// Copyright (c) 2026 Unlabel contributors. SPDX-License-Identifier: MIT
package main

import (
	"net/http"
	"os"
	"strconv"
	"time"
)

func probe(endpoint string) bool {
	client := &http.Client{
		Timeout:   3 * time.Second,
		Transport: &http.Transport{Proxy: nil, DisableKeepAlives: true},
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	response, err := client.Get(endpoint)
	if err != nil {
		return false
	}
	defer response.Body.Close()
	return response.StatusCode == http.StatusOK
}

func main() {
	port := os.Getenv("GOTRUE_API_PORT")
	if port == "" {
		port = "9999"
	}
	number, err := strconv.Atoi(port)
	if err != nil || number < 1 || number > 65535 {
		os.Exit(1)
	}
	if !probe("http://127.0.0.1:" + strconv.Itoa(number) + "/health") {
		os.Exit(1)
	}
}
