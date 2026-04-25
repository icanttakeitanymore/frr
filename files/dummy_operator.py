#!/usr/bin/env python3

import time
import requests
import subprocess
import argparse
import logging


def set_iface(iface, state):
    subprocess.call(["ip", "link", "set", iface, state])


def check(url, timeout, ok_codes):
    try:
        r = requests.get(url, timeout=timeout / 1000.0)
        return r.status_code in ok_codes
    except Exception:
        return False


def main():
    parser = argparse.ArgumentParser(description="Dummy interface health operator")

    parser.add_argument("--iface", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--ok-codes", default="200")
    parser.add_argument("--fail-threshold", type=int, default=3)
    parser.add_argument("--raise-threshold", type=int, default=1)
    parser.add_argument("--interval", type=int, default=1000, help="ms")
    parser.add_argument("--timeout", type=int, default=1000, help="ms")

    args = parser.parse_args()

    ok_codes = list(map(int, args.ok_codes.split(",")))

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s"
    )

    fails = 0
    oks = 0
    state = None

    logging.info(f"Starting dummy operator for {args.iface} → {args.url}")

    while True:
        ok = check(args.url, args.timeout, ok_codes)

        if ok:
            oks += 1
            fails = 0
        else:
            fails += 1
            oks = 0

        # DOWN
        if fails >= args.fail_threshold and state != "down":
            logging.warning(f"{args.iface}: DOWN (fails={fails})")
            set_iface(args.iface, "down")
            state = "down"

        # UP
        if oks >= args.raise_threshold and state != "up":
            logging.info(f"{args.iface}: UP (oks={oks})")
            set_iface(args.iface, "up")
            state = "up"

        time.sleep(args.interval / 1000.0)


if __name__ == "__main__":
    main()