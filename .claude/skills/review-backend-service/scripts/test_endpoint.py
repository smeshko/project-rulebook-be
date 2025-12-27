#!/usr/bin/env python3
"""
Test an HTTP endpoint and return structured response data.

Usage:
    python test_endpoint.py --method GET --url "http://localhost:3000/api/users"
    python test_endpoint.py --method POST --url "http://localhost:3000/api/users" --body '{"name": "test"}'
    python test_endpoint.py --method GET --url "http://localhost:3000/api/users" --auth-header "Bearer token123"
"""

import argparse
import json
import sys
import time
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError


def test_endpoint(method: str, url: str, headers: dict = None, body: str = None, timeout: int = 30) -> dict:
    """
    Test an HTTP endpoint and return structured response data.

    Returns:
        dict with request, response, duration_ms, and error fields
    """
    headers = headers or {}

    # Add default headers
    if "Content-Type" not in headers and body:
        headers["Content-Type"] = "application/json"
    if "Accept" not in headers:
        headers["Accept"] = "application/json"

    result = {
        "request": {
            "method": method,
            "url": url,
            "headers": headers,
            "body": body
        },
        "response": None,
        "duration_ms": 0,
        "error": None
    }

    try:
        # Prepare request
        data = body.encode("utf-8") if body else None
        req = Request(url, data=data, headers=headers, method=method)

        # Execute request with timing
        start_time = time.time()
        with urlopen(req, timeout=timeout) as response:
            end_time = time.time()

            response_body = response.read().decode("utf-8")

            # Try to parse as JSON
            try:
                response_body = json.loads(response_body)
            except json.JSONDecodeError:
                pass  # Keep as string

            result["response"] = {
                "status": response.status,
                "headers": dict(response.headers),
                "body": response_body
            }
            result["duration_ms"] = round((end_time - start_time) * 1000)

    except HTTPError as e:
        end_time = time.time()
        response_body = e.read().decode("utf-8") if e.fp else ""

        try:
            response_body = json.loads(response_body)
        except json.JSONDecodeError:
            pass

        result["response"] = {
            "status": e.code,
            "headers": dict(e.headers) if e.headers else {},
            "body": response_body
        }
        result["duration_ms"] = round((end_time - start_time) * 1000)

    except URLError as e:
        result["error"] = f"Connection error: {e.reason}"

    except TimeoutError:
        result["error"] = f"Request timed out after {timeout}s"

    except Exception as e:
        result["error"] = f"Unexpected error: {str(e)}"

    return result


def main():
    parser = argparse.ArgumentParser(description="Test an HTTP endpoint")
    parser.add_argument("--method", required=True, help="HTTP method (GET, POST, PUT, DELETE, PATCH)")
    parser.add_argument("--url", required=True, help="Full URL to test")
    parser.add_argument("--body", help="Request body (JSON string)")
    parser.add_argument("--auth-header", dest="auth_header", help="Authorization header value")
    parser.add_argument("--header", action="append", dest="headers", help="Additional headers (format: 'Name: Value')")
    parser.add_argument("--timeout", type=int, default=30, help="Request timeout in seconds")

    args = parser.parse_args()

    # Build headers dict
    headers = {}
    if args.auth_header:
        headers["Authorization"] = args.auth_header
    if args.headers:
        for h in args.headers:
            if ": " in h:
                name, value = h.split(": ", 1)
                headers[name] = value

    # Test the endpoint
    result = test_endpoint(
        method=args.method.upper(),
        url=args.url,
        headers=headers,
        body=args.body,
        timeout=args.timeout
    )

    # Output as JSON
    print(json.dumps(result, indent=2))

    # Exit with error code if request failed
    if result["error"]:
        sys.exit(1)
    elif result["response"] and result["response"]["status"] >= 400:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
