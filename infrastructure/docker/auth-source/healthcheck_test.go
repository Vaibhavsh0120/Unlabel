// Copyright (c) 2026 Unlabel contributors. SPDX-License-Identifier: MIT
package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestProbeAcceptsOnlyHealthyResponse(t *testing.T) {
	for _, status := range []int{http.StatusOK, http.StatusServiceUnavailable, http.StatusUnauthorized} {
		t.Run(http.StatusText(status), func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path != "/health" {
					t.Errorf("unexpected path %s", r.URL.Path)
				}
				w.WriteHeader(status)
			}))
			defer server.Close()
			if result := probe(server.URL + "/health"); result != (status == http.StatusOK) {
				t.Errorf("status %d produced health %v", status, result)
			}
		})
	}
}

func TestProbeRejectsRedirectWithoutFollowingIt(t *testing.T) {
	followed := false
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		followed = true
		w.WriteHeader(http.StatusOK)
	}))
	defer target.Close()
	redirect := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, target.URL, http.StatusFound)
	}))
	defer redirect.Close()
	if probe(redirect.URL) || followed {
		t.Fatal("healthcheck must not follow redirects")
	}
}

func TestProbeRejectsConnectionFailure(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	endpoint := server.URL
	server.Close()
	if probe(endpoint) {
		t.Fatal("closed service reported healthy")
	}
}
